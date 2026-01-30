from flask import Flask, request, jsonify
import json
import os
import subprocess
import logging
from datetime import datetime

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


@app.route("/upscale-trigger", methods=["POST"])
def handle_play():
    """
    Handle webhook trigger from Jellyfin playback events.

    Supports two modes:
    1. Streaming mode (default): Returns HLS URL for real-time playback
    2. Batch mode: Queues job for background processing
    """
    try:
        # Log the raw request for debugging
        logger.info("=" * 80)
        logger.info("Webhook received!")
        logger.info(f"Content-Type: {request.content_type}")
        logger.info(f"Method: {request.method}")

        # Parse JSON payload - handle different content types
        data = None

        # Try to parse as JSON
        if request.is_json:
            data = request.json
            logger.info("✓ Parsed as JSON from Content-Type header")
        else:
            # Try to parse body as JSON even if content-type is wrong
            try:
                data = json.loads(request.data.decode('utf-8'))
                logger.warning(f"⚠️ Content-Type is '{request.content_type}' but body is valid JSON")
                logger.warning("   Please set Content-Type: application/json in Jellyfin webhook")
            except (json.JSONDecodeError, UnicodeDecodeError) as e:
                logger.error(f"ERROR: Failed to parse request body as JSON: {e}")
                logger.error(f"Content-Type: {request.content_type}")
                logger.error(f"Body (first 500 chars): {request.data[:500]}")
                return jsonify({
                    "status": "error",
                    "message": "Invalid JSON payload. Please set Content-Type: application/json in Jellyfin webhook",
                    "content_type_received": request.content_type,
                    "expected": "application/json"
                }), 400

        if not data:
            data = {}

        logger.info(f"Full payload: {json.dumps(data, indent=2)}")

        # Extract file path - support both flat and nested structures
        input_file = data.get("Path") or data.get("Item", {}).get("Path")
        logger.info(f"Extracted file path: {input_file}")

        if not input_file:
            logger.error("ERROR: No file path found in webhook payload!")
            logger.error("Expected: data['Path'] or data['Item']['Path']")
            logger.error(f"Received keys: {list(data.keys())}")

            # Check if it's an empty template variable issue
            if "Path" in data and data["Path"] == "":
                logger.error("")
                logger.error("╔════════════════════════════════════════════════════════════╗")
                logger.error("║  JELLYFIN WEBHOOK MISCONFIGURATION DETECTED                ║")
                logger.error("╚════════════════════════════════════════════════════════════╝")
                logger.error("")
                logger.error("Template variables are EMPTY ({{Path}} = '')")
                logger.error("")
                logger.error("COMMON CAUSES:")
                logger.error("  1. Wrong Notification Type selected")
                logger.error("     → Must be: Playback Start")
                logger.error("")
                logger.error("  2. Wrong Item Type selected")
                logger.error("     → Must be: Movie and/or Episode")
                logger.error("")
                logger.error("  3. Template uses wrong syntax")
                logger.error("     → Correct: {{Path}} (flat structure, double braces)")
                logger.error("     → Wrong: {{Item.Path}} or {{{Path}}}")
                logger.error("")
                logger.error("  4. Webhook plugin not patched with Path variable")
                logger.error("     → Install patched version from jellyfin-plugin-webhook/")
                logger.error("")
                logger.error("FIX: In Jellyfin Dashboard → Plugins → Webhooks:")
                logger.error("  1. Edit your webhook")
                logger.error("  2. Check 'Playback Start' under Notification Type")
                logger.error("  3. Check 'Movie' and 'Episode' under Item Type")
                logger.error("  4. Verify template uses {{Path}} (double braces, flat)")
                logger.error("  5. Save and test by playing a video")
                logger.error("")
                logger.error("See: WEBHOOK_CONFIGURATION_CORRECT.md for complete configuration")
                logger.error("")

                return jsonify({
                    "status": "error",
                    "message": "Webhook template variables are empty",
                    "issue": "Path is empty string - Jellyfin not filling template",
                    "fix": "Check Notification Type (Playback Start) and Item Type (Movie/Episode) in webhook config",
                    "documentation": "See WEBHOOK_CONFIGURATION_CORRECT.md"
                }), 400

            return jsonify({
                "status": "error",
                "message": "Missing Path in payload"
            }), 400

        # Check if file exists
        if not os.path.exists(input_file):
            logger.error(f"ERROR: Input file does not exist: {input_file}")
            logger.error("Possible causes:")
            logger.error("  1. Path mismatch between Jellyfin and watchdog host")
            logger.error("  2. File permissions issue")
            logger.error("  3. Network mount not accessible")
            return jsonify({
                "status": "error",
                "message": f"File not found: {input_file}"
            }), 404

        logger.info(f"✓ File exists: {input_file}")

        # Setup output directory and file
        upscaled_dir = os.environ.get("UPSCALED_DIR", "/data/upscaled")
        logger.info(f"Output directory: {upscaled_dir}")

        # Create output directory if it doesn't exist
        if not os.path.exists(upscaled_dir):
            logger.info(f"Creating output directory: {upscaled_dir}")
            try:
                os.makedirs(upscaled_dir, exist_ok=True)
            except Exception as e:
                logger.error(f"ERROR: Failed to create output directory: {e}")
                return jsonify({
                    "status": "error",
                    "message": f"Cannot create output directory: {e}"
                }), 500

        base_name = os.path.splitext(os.path.basename(input_file))[0]
        output_file = os.path.join(upscaled_dir, f"{base_name}.ts")
        logger.info(f"Output file will be: {output_file}")

        # Check if already upscaled
        if os.path.exists(output_file):
            logger.info(f"✓ Output file already exists: {output_file}")
            return jsonify({
                "status": "ready",
                "message": "File already upscaled - use existing file",
                "file": output_file,
                "upscaled": True
            }), 200

        # Check if streaming mode is enabled
        enable_streaming = os.environ.get("ENABLE_HLS_STREAMING", "1") == "1"

        if enable_streaming:
            # HLS streaming mode
            hls_dir = os.path.join(upscaled_dir, "hls", base_name)
            hls_playlist = os.path.join(hls_dir, "stream.m3u8")

            logger.info(f"Streaming mode enabled")
            logger.info(f"HLS directory: {hls_dir}")

            # Create HLS directory
            try:
                os.makedirs(hls_dir, exist_ok=True)
            except Exception as e:
                logger.error(f"ERROR: Failed to create HLS directory: {e}")
                return jsonify({
                    "status": "error",
                    "message": f"Cannot create HLS directory: {e}"
                }), 500

            # Check if HLS stream already in progress
            if os.path.exists(hls_playlist):
                logger.info(f"⚠ HLS stream already in progress: {hls_playlist}")

                # Get HLS server URL
                hls_server_host = os.environ.get("HLS_SERVER_HOST", "localhost")
                hls_server_port = os.environ.get("HLS_SERVER_PORT", "8080")
                hls_url = f"http://{hls_server_host}:{hls_server_port}/hls/{base_name}/stream.m3u8"

                return jsonify({
                    "status": "streaming",
                    "message": "Upscaling already in progress",
                    "hls_url": hls_url,
                    "playlist": hls_playlist,
                    "final_file": output_file
                }), 200

            # Add to queue with streaming metadata
            queue_file = os.environ.get("SRGAN_QUEUE_FILE", "./cache/queue.jsonl")
            logger.info(f"Queue file: {queue_file}")

            os.makedirs(os.path.dirname(queue_file), exist_ok=True)
            payload = json.dumps({
                "input": input_file,
                "output": output_file,
                "hls_dir": hls_dir,
                "streaming": True
            })

            with open(queue_file, "a", encoding="utf-8") as handle:
                handle.write(f"{payload}\n")

            logger.info(f"✓ Streaming job added to queue")
            logger.info(f"  Input:      {input_file}")
            logger.info(f"  Output:     {output_file}")
            logger.info(f"  HLS dir:    {hls_dir}")

            # Start the upscaler container
            logger.info("Starting srgan-upscaler container...")
            try:
                result = subprocess.run(
                    ["docker", "compose", "up", "-d", "srgan-upscaler"],
                    capture_output=True,
                    text=True,
                    timeout=30
                )

                if result.returncode == 0:
                    logger.info("✓ Docker compose command successful")
                else:
                    logger.error(f"Docker compose error: {result.stderr}")
                    return jsonify({
                        "status": "error",
                        "message": f"Docker error: {result.stderr}"
                    }), 500

            except subprocess.TimeoutExpired:
                logger.error("Docker compose command timed out")
            except FileNotFoundError:
                logger.error("ERROR: 'docker' command not found. Is Docker installed?")
                return jsonify({
                    "status": "error",
                    "message": "Docker not found"
                }), 500

            # Get HLS server URL
            hls_server_host = os.environ.get("HLS_SERVER_HOST", "localhost")
            hls_server_port = os.environ.get("HLS_SERVER_PORT", "8080")
            hls_url = f"http://{hls_server_host}:{hls_server_port}/hls/{base_name}/stream.m3u8"

            logger.info(f"✓ HLS stream will be available at: {hls_url}")
            logger.info(f"  Estimated delay: 10-15 seconds")
            logger.info("=" * 80)

            return jsonify({
                "status": "started",
                "message": "HLS upscaling started - stream will be available shortly",
                "hls_url": hls_url,
                "playlist": hls_playlist,
                "final_file": output_file,
                "estimated_delay_seconds": 15,
                "streaming": True
            }), 200

        else:
            # Batch mode (original behavior)
            logger.info("Batch mode enabled")

            queue_file = os.environ.get("SRGAN_QUEUE_FILE", "./cache/queue.jsonl")
            os.makedirs(os.path.dirname(queue_file), exist_ok=True)
            payload = json.dumps({
                "input": input_file,
                "output": output_file,
                "streaming": False
            })

            with open(queue_file, "a", encoding="utf-8") as handle:
                handle.write(f"{payload}\n")

            logger.info(f"✓ Batch job added to queue: {queue_file}")
            logger.info(f"  Input:  {input_file}")
            logger.info(f"  Output: {output_file}")

            # Start the upscaler container
            logger.info("Starting srgan-upscaler container...")
            try:
                result = subprocess.run(
                    ["docker", "compose", "up", "-d", "srgan-upscaler"],
                    capture_output=True,
                    text=True,
                    timeout=30
                )

                if result.returncode == 0:
                    logger.info("✓ Docker compose command successful")
                else:
                    logger.error(f"Docker compose error: {result.stderr}")
                    return jsonify({
                        "status": "error",
                        "message": f"Docker error: {result.stderr}"
                    }), 500

            except subprocess.TimeoutExpired:
                logger.error("Docker compose command timed out")
            except FileNotFoundError:
                logger.error("ERROR: 'docker' command not found. Is Docker installed?")
                return jsonify({
                    "status": "error",
                    "message": "Docker not found"
                }), 500

            logger.info("✓ Upscale job queued successfully!")
            logger.info("=" * 80)

            return jsonify({
                "status": "success",
                "message": "Job queued for upscaling",
                "input": input_file,
                "output": output_file,
                "streaming": False
            }), 200

    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "upscaled_dir": os.environ.get("UPSCALED_DIR", "/data/upscaled"),
        "queue_file": os.environ.get("SRGAN_QUEUE_FILE", "./cache/queue.jsonl"),
        "streaming_enabled": os.environ.get("ENABLE_HLS_STREAMING", "1") == "1"
    }), 200


@app.route("/hls-status/<filename>", methods=["GET"])
def hls_status(filename):
    """
    Check HLS streaming status for a specific file.

    Returns:
    - ready: Final file exists, use that
    - streaming: HLS in progress, use HLS URL
    - not_started: Neither exists yet
    """
    try:
        upscaled_dir = os.environ.get("UPSCALED_DIR", "/data/upscaled")
        base_name = os.path.splitext(filename)[0]

        output_file = os.path.join(upscaled_dir, f"{base_name}.ts")
        hls_dir = os.path.join(upscaled_dir, "hls", base_name)
        hls_playlist = os.path.join(hls_dir, "stream.m3u8")

        # Check if final file exists
        if os.path.exists(output_file):
            file_size = os.path.getsize(output_file)
            return jsonify({
                "status": "ready",
                "message": "Final upscaled file available",
                "file": output_file,
                "size": file_size,
                "upscaled": True
            }), 200

        # Check if HLS stream is in progress
        if os.path.exists(hls_playlist):
            # Count segments
            segments = [f for f in os.listdir(hls_dir) if f.endswith('.ts')] if os.path.exists(hls_dir) else []

            # Check if completed (has EXT-X-ENDLIST)
            with open(hls_playlist, 'r') as f:
                playlist_content = f.read()
                is_complete = '#EXT-X-ENDLIST' in playlist_content

            hls_server_host = os.environ.get("HLS_SERVER_HOST", "localhost")
            hls_server_port = os.environ.get("HLS_SERVER_PORT", "8080")
            hls_url = f"http://{hls_server_host}:{hls_server_port}/hls/{base_name}/stream.m3u8"

            return jsonify({
                "status": "streaming" if not is_complete else "finalizing",
                "message": "HLS stream in progress" if not is_complete else "Stream complete, finalizing file",
                "hls_url": hls_url,
                "playlist": hls_playlist,
                "segments": len(segments),
                "complete": is_complete
            }), 200

        # Nothing exists yet
        return jsonify({
            "status": "not_started",
            "message": "Upscaling not started yet"
        }), 404

    except Exception as e:
        logger.exception(f"Error checking HLS status: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route("/progress/<filename>", methods=["GET"])
def get_progress(filename):
    """
    Get detailed upscaling progress for display in Jellyfin playback overlay.

    Returns detailed progress information including:
    - Progress percentage
    - Processing speed
    - ETA
    - Segment count
    - Status message
    """
    try:
        import subprocess
        import time

        upscaled_dir = os.environ.get("UPSCALED_DIR", "/data/upscaled")
        base_name = os.path.splitext(filename)[0]

        output_file = os.path.join(upscaled_dir, f"{base_name}.ts")
        hls_dir = os.path.join(upscaled_dir, "hls", base_name)
        hls_playlist = os.path.join(hls_dir, "stream.m3u8")

        # Check if already complete
        if os.path.exists(output_file):
            file_size = os.path.getsize(output_file)
            file_size_mb = file_size / (1024 * 1024)

            return jsonify({
                "status": "complete",
                "progress": 100,
                "message": "Upscaling complete",
                "file_size_mb": round(file_size_mb, 2),
                "available": True
            }), 200

        # Check if upscaling in progress
        if not os.path.exists(hls_playlist):
            return jsonify({
                "status": "not_started",
                "progress": 0,
                "message": "Upscaling not started"
            }), 404

        # Get segment info
        segments = sorted([
            f for f in os.listdir(hls_dir)
            if f.startswith('segment_') and f.endswith('.ts')
        ]) if os.path.exists(hls_dir) else []

        segment_count = len(segments)

        # Get segment duration from environment
        segment_duration = int(os.environ.get("HLS_SEGMENT_TIME", "6"))
        current_duration = segment_count * segment_duration

        # Try to detect video duration from input file
        # Check queue file for input path
        queue_file = os.environ.get("SRGAN_QUEUE_FILE", "./cache/queue.jsonl")
        input_file = None
        total_duration = None

        if os.path.exists(queue_file):
            try:
                with open(queue_file, 'r', encoding='utf-8') as f:
                    for line in f:
                        try:
                            job = json.loads(line.strip())
                            if base_name in job.get('output', ''):
                                input_file = job.get('input')
                                break
                        except:
                            pass
            except:
                pass

        # Try to get duration using ffprobe
        if input_file and os.path.exists(input_file):
            try:
                cmd = [
                    "ffprobe",
                    "-v", "error",
                    "-show_entries", "format=duration",
                    "-of", "default=noprint_wrappers=1:nokey=1",
                    input_file
                ]
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    total_duration = float(result.stdout.strip())
            except:
                pass

        # Check if completed
        is_complete = False
        with open(hls_playlist, 'r') as f:
            playlist_content = f.read()
            is_complete = '#EXT-X-ENDLIST' in playlist_content

        # Calculate progress
        progress = 0
        eta_seconds = None
        processing_rate = 0

        if total_duration and total_duration > 0:
            progress = min(100, (current_duration / total_duration) * 100)

            # Estimate processing rate (segments per second)
            # Get HLS directory creation time as start time
            if os.path.exists(hls_dir):
                dir_mtime = os.path.getmtime(hls_dir)
                elapsed = time.time() - dir_mtime

                if elapsed > 0:
                    processing_rate = current_duration / elapsed

                    if processing_rate > 0:
                        remaining = total_duration - current_duration
                        eta_seconds = int(remaining / processing_rate)

        # Build response
        response = {
            "status": "finalizing" if is_complete else "processing",
            "progress": round(progress, 1),
            "segments": segment_count,
            "current_duration": current_duration,
            "processing_rate": round(processing_rate, 2),
            "available": segment_count > 0
        }

        if total_duration:
            response["total_duration"] = int(total_duration)
            response["eta_seconds"] = eta_seconds

        # Status message
        if is_complete:
            response["message"] = "Finalizing upscaled file..."
        elif segment_count == 0:
            response["message"] = "Starting upscale process..."
        elif processing_rate >= 1.0:
            response["message"] = f"Upscaling at {processing_rate:.1f}x speed"
        elif processing_rate > 0:
            response["message"] = f"Upscaling (slower than real-time: {processing_rate:.1f}x)"
        else:
            response["message"] = "Upscaling in progress..."

        # HLS URL
        hls_server_host = os.environ.get("HLS_SERVER_HOST", "localhost")
        hls_server_port = os.environ.get("HLS_SERVER_PORT", "8080")
        response["hls_url"] = f"http://{hls_server_host}:{hls_server_port}/hls/{base_name}/stream.m3u8"

        return jsonify(response), 200

    except Exception as e:
        logger.exception(f"Error getting progress: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route("/", methods=["GET"])
def index():
    """Root endpoint with usage information."""
    return jsonify({
        "service": "SRGAN Upscaler Watchdog",
        "endpoints": {
            "/upscale-trigger": "POST - Webhook endpoint for Jellyfin",
            "/health": "GET - Health check",
            "/": "GET - This message"
        }
    }), 200


if __name__ == "__main__":
    logger.info("=" * 80)
    logger.info("SRGAN Upscaler Watchdog Starting")
    logger.info("=" * 80)
    logger.info(f"Listening on: http://0.0.0.0:5000")
    logger.info(f"Webhook endpoint: http://0.0.0.0:5000/upscale-trigger")
    logger.info(f"Health check: http://0.0.0.0:5000/health")
    logger.info(f"HLS status: http://0.0.0.0:5000/hls-status/<filename>")
    logger.info(f"Output directory: {os.environ.get('UPSCALED_DIR', '/data/upscaled')}")
    logger.info(f"Queue file: {os.environ.get('SRGAN_QUEUE_FILE', './cache/queue.jsonl')}")

    streaming_enabled = os.environ.get('ENABLE_HLS_STREAMING', '1') == '1'
    logger.info(f"Streaming mode: {'ENABLED' if streaming_enabled else 'DISABLED'}")

    if streaming_enabled:
        hls_server_host = os.environ.get("HLS_SERVER_HOST", "localhost")
        hls_server_port = os.environ.get("HLS_SERVER_PORT", "8080")
        logger.info(f"HLS server: http://{hls_server_host}:{hls_server_port}/hls/")

    logger.info("=" * 80)
    app.run(host="0.0.0.0", port=5000, debug=False)
