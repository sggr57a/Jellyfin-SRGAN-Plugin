#!/usr/bin/env python3
"""
SRGAN Pipeline - Main video upscaling pipeline
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time


def _ensure_parent_dir(path):
    parent = os.path.dirname(os.path.abspath(path))
    if parent and not os.path.exists(parent):
        os.makedirs(parent, exist_ok=True)


def _get_video_info(input_path):
    """
    Get video information using ffprobe.
    Returns dict with resolution, HDR info, etc.
    """
    try:
        cmd = [
            "ffprobe",
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height,color_space,color_transfer,color_primaries",
            "-of", "json",
            input_path
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(result.stdout)
        
        if not data.get("streams"):
            return None
        
        stream = data["streams"][0]
        width = int(stream.get("width", 0))
        height = int(stream.get("height", 0))
        
        # Detect HDR
        color_transfer = stream.get("color_transfer", "")
        color_space = stream.get("color_space", "")
        color_primaries = stream.get("color_primaries", "")
        
        is_hdr = (
            "smpte2084" in color_transfer.lower() or  # HDR10
            "arib-std-b67" in color_transfer.lower() or  # HLG
            "bt2020" in color_space.lower() or
            "bt2020" in color_primaries.lower()
        )
        
        return {
            "width": width,
            "height": height,
            "is_hdr": is_hdr,
            "color_transfer": color_transfer,
            "color_space": color_space,
        }
    except Exception as e:
        print(f"Warning: Could not get video info: {e}", file=sys.stderr)
        return None


def _resolution_to_label(height):
    """Convert resolution height to standard label."""
    if height >= 2160:
        return "2160p"  # 4K
    elif height >= 1440:
        return "1440p"  # 2K
    elif height >= 1080:
        return "1080p"  # Full HD
    elif height >= 720:
        return "720p"   # HD
    elif height >= 576:
        return "576p"   # SD
    elif height >= 480:
        return "480p"   # SD
    else:
        return f"{height}p"


def _generate_output_filename(input_path, output_dir, target_height, is_hdr=False, output_ext=None):
    """
    Generate intelligent output filename with resolution and HDR tags.
    
    Examples:
        Movie (2020) [720p].mkv → Movie (2020) [2160p].mkv
        Movie (2020) [1080p].mkv → Movie (2020) [2160p] [HDR].mkv
        Movie (2020).mkv → Movie (2020) [2160p].mkv
    """
    basename = os.path.basename(input_path)
    name_without_ext = os.path.splitext(basename)[0]
    
    # Determine output extension
    if output_ext is None:
        output_format = os.environ.get("OUTPUT_FORMAT", "mkv").lower()
        output_ext = f".{output_format}" if not output_format.startswith(".") else output_format
    
    # Remove existing resolution tags (480p, 576p, 720p, 1080p, 1440p, 2160p, 4K, etc.)
    # Handle both standalone tags and compound tags like "Bluray-1080p"
    resolution_patterns = [
        r'[-\s]?(480|576|720|1080|1440|2160)[pi]\b',  # Handles "720p" and "Bluray-720p"
        r'\[?\b4K\b\]?',
        r'\[?\b2K\b\]?',
        r'\[?\bHD\b\]?',
        r'\[?\bFHD\b\]?',
        r'\[?\bUHD\b\]?',
        r'\[?\bSD\b\]?',
    ]
    
    for pattern in resolution_patterns:
        name_without_ext = re.sub(pattern, '', name_without_ext, flags=re.IGNORECASE)
    
    # Remove existing HDR tags
    hdr_patterns = [
        r'\[?\bHDR10?\b\]?',
        r'\[?\bHDR\b\]?',
        r'\[?\bDolby Vision\b\]?',
        r'\[?\bHLG\b\]?',
    ]
    
    for pattern in hdr_patterns:
        name_without_ext = re.sub(pattern, '', name_without_ext, flags=re.IGNORECASE)
    
    # Clean up multiple spaces and brackets
    name_without_ext = re.sub(r'\s+', ' ', name_without_ext)
    name_without_ext = re.sub(r'\[\s*\]', '', name_without_ext)
    name_without_ext = name_without_ext.strip()
    
    # Add new resolution tag
    new_resolution = _resolution_to_label(target_height)
    name_without_ext = f"{name_without_ext} [{new_resolution}]"
    
    # Add HDR tag if applicable
    if is_hdr:
        name_without_ext = f"{name_without_ext} [HDR]"
    
    # Generate final output path
    output_filename = f"{name_without_ext}{output_ext}"
    return os.path.join(output_dir, output_filename)


def _run_ffmpeg(input_path, output_path, width, height):
    """
    DEPRECATED: Legacy FFmpeg-only upscaling (no AI).
    This function is NO LONGER USED and will be removed.
    Normal operation uses AI upscaling via _try_model().
    """
    raise NotImplementedError("FFmpeg-only upscaling is no longer supported. Use AI upscaling (SRGAN_ENABLE=1).")


def _escape_tee_path(path):
    """
    Escape special characters in file paths for FFmpeg tee muxer.
    Tee muxer treats [, ], :, | as special characters.
    """
    # Escape special characters for tee muxer
    path = path.replace("'", "'\\''")  # Single quotes
    path = path.replace("[", r"\[")    # Opening bracket
    path = path.replace("]", r"\]")    # Closing bracket
    path = path.replace(":", r"\:")    # Colon (in non-URL contexts)
    return path


def _run_ffmpeg_direct(input_path, output_path, width, height):
    """
    DEPRECATED: Legacy FFmpeg-only direct output (no AI).
    This function is NO LONGER USED and will be removed.
    Normal operation uses AI upscaling via _try_model().
    """
    raise NotImplementedError("FFmpeg-only upscaling is no longer supported. Use AI upscaling (SRGAN_ENABLE=1).")
    
    # Video filter
    if width and height:
        vf = f"scale={width}:{height}:flags=lanczos"
    else:
        # Default to 2x upscale if no dimensions specified
        scale_factor = float(os.environ.get("SRGAN_SCALE_FACTOR", "2.0"))
        vf = f"scale=iw*{scale_factor}:ih*{scale_factor}:flags=lanczos"
    
    # Hardware acceleration
    hwaccel = os.environ.get("SRGAN_FFMPEG_HWACCEL", "0") == "1"
    rtbufsize = os.environ.get("SRGAN_FFMPEG_RTBUFSIZE")
    encoder = os.environ.get("SRGAN_FFMPEG_ENCODER", "hevc_nvenc")
    preset_default = "p4" if "nvenc" in encoder else "fast"
    preset = os.environ.get("SRGAN_FFMPEG_PRESET", preset_default)
    bufsize = os.environ.get("SRGAN_FFMPEG_BUFSIZE")
    
    input_opts = []
    if hwaccel:
        input_opts.extend(["-hwaccel", "cuda"])
    if rtbufsize:
        input_opts.extend(["-rtbufsize", rtbufsize])
    
    # Build command for direct output
    cmd = [
        "ffmpeg",
        "-y",
        *input_opts,
        "-i", input_path,
        "-vf", vf,
        "-c:v", encoder,
        "-preset", preset,
    ]
    
    # Use appropriate quality option based on encoder
    if "nvenc" in encoder.lower():
        # NVENC encoders use -cq (Constant Quality)
        cmd.extend(["-cq", "23"])
    else:
        # Software encoders use -crf (Constant Rate Factor)
        cmd.extend(["-crf", "18"])
    
    # Audio and subtitle handling
    cmd.extend([
        "-c:a", "copy",      # Copy all audio streams
        "-c:s", "copy",      # Copy all subtitle streams
    ])
    
    if bufsize:
        cmd.extend(["-bufsize", bufsize])
    
    # Map all streams
    cmd.extend(["-map", "0"])
    
    # Set container format
    if output_ext == '.mp4':
        cmd.extend(["-movflags", "+faststart"])  # Enable streaming for MP4
    
    cmd.append(output_path)
    
    print(f"Starting direct file upscale:", file=sys.stderr)
    print(f"  Input:  {input_path}", file=sys.stderr)
    print(f"  Output: {output_path}", file=sys.stderr)
    print(f"  Format: {output_ext.upper()}", file=sys.stderr)
    print(f"  Video:  {encoder} (quality preset)", file=sys.stderr)
    print(f"  Audio:  Copy all streams", file=sys.stderr)
    print(f"  Subs:   Copy all streams", file=sys.stderr)
    print("", file=sys.stderr)
    
    subprocess.check_call(cmd)
    
    print(f"✓ Upscaling complete: {output_path}", file=sys.stderr)


def _run_ffmpeg_streaming(input_path, output_path, hls_dir, width, height):
    """
    REMOVED: HLS streaming mode is no longer supported.
    All output is direct MKV/MP4 files only.
    """
    raise NotImplementedError(
        "HLS streaming mode has been removed. "
        "Only direct MKV/MP4 output is supported. "
        "Set streaming=False in job queue."
    )


def _finalize_hls_playlist(hls_playlist):
    """REMOVED: HLS playlist finalization no longer needed."""
    raise NotImplementedError("HLS streaming has been removed.")


def _verify_upscaled_output(output_path, expected_height=None, input_path=None):
    """
    Verify that the upscaled output file is valid and meets expectations.
    
    Returns:
        tuple: (success: bool, verification_info: dict)
    """
    verification = {
        "exists": False,
        "valid": False,
        "resolution": None,
        "file_size": None,
        "codec": None,
        "duration": None,
        "error": None
    }
    
    # Check file exists
    if not os.path.exists(output_path):
        verification["error"] = "Output file does not exist"
        return False, verification
    
    verification["exists"] = True
    
    # Get file size
    try:
        file_size = os.path.getsize(output_path)
        verification["file_size"] = file_size
        
        # Sanity check: file should be > 1MB
        if file_size < 1_000_000:
            verification["error"] = f"Output file too small: {file_size} bytes"
            return False, verification
    except Exception as e:
        verification["error"] = f"Could not get file size: {e}"
        return False, verification
    
    # Verify with ffprobe
    try:
        cmd = [
            "ffprobe",
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height,codec_name,duration:format=duration",
            "-of", "json",
            output_path
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=30)
        data = json.loads(result.stdout)
        
        if not data.get("streams"):
            verification["error"] = "No video stream found in output"
            return False, verification
        
        stream = data["streams"][0]
        width = int(stream.get("width", 0))
        height = int(stream.get("height", 0))
        codec = stream.get("codec_name", "unknown")
        
        verification["resolution"] = f"{width}x{height}"
        verification["codec"] = codec
        
        # Get duration
        duration = stream.get("duration") or data.get("format", {}).get("duration")
        if duration:
            verification["duration"] = float(duration)
        
        # Check resolution matches expected
        if expected_height and height > 0:
            if abs(height - expected_height) > 10:  # Allow 10px tolerance
                verification["error"] = f"Resolution mismatch: expected {expected_height}p, got {height}p"
                return False, verification
        
        # If we have input path, compare durations
        if input_path and verification["duration"]:
            input_info = _get_video_info(input_path)
            # Duration check would go here if needed
        
        verification["valid"] = True
        return True, verification
        
    except subprocess.TimeoutExpired:
        verification["error"] = "ffprobe timeout"
        return False, verification
    except Exception as e:
        verification["error"] = f"ffprobe failed: {e}"
        return False, verification


def _try_model(input_path, output_path, width, height, scale):
    """
    Try to upscale using AI model with intelligent output naming and verification.
    """
    # Try FFmpeg-based implementation first (more reliable)
    try:
        import your_model_file_ffmpeg as model_module
        print("Using FFmpeg-based AI upscaling (recommended)", file=sys.stderr)
    except ImportError:
        # Fallback to torchaudio.io version
        try:
            import your_model_file as model_module
            print("Using torchaudio.io-based AI upscaling", file=sys.stderr)
        except Exception as e:
            print(f"ERROR: Could not import AI model: {e}", file=sys.stderr)
            return False

    upscale = getattr(model_module, "upscale", None)
    if not callable(upscale):
        print(f"ERROR: Model 'upscale' function not found", file=sys.stderr)
        return False

    try:
        # Get input video information for intelligent naming
        video_info = _get_video_info(input_path)
        
        # Calculate target resolution
        if width and height:
            target_height = height
        else:
            scale_factor = float(os.environ.get("SRGAN_SCALE_FACTOR", "2.0"))
            if video_info and video_info.get("height"):
                target_height = int(video_info["height"] * scale_factor)
            else:
                target_height = 2160  # Default assume 4K output
        
        # Generate intelligent output filename with resolution and HDR tags
        output_dir = os.path.dirname(output_path)
        output_ext = os.path.splitext(output_path)[1]
        is_hdr = video_info.get("is_hdr", False) if video_info else False
        
        # Generate new filename
        intelligent_output_path = _generate_output_filename(
            input_path, 
            output_dir, 
            target_height, 
            is_hdr,
            output_ext
        )
        
        # Log the intelligent naming
        print(f"Intelligent filename generation:", file=sys.stderr)
        if video_info:
            print(f"  Input resolution: {video_info.get('width')}x{video_info.get('height')} ({video_info.get('height')}p)", file=sys.stderr)
        print(f"  Target resolution: {target_height}p", file=sys.stderr)
        print(f"  HDR detected: {'Yes' if is_hdr else 'No'}", file=sys.stderr)
        print(f"  Output file: {os.path.basename(intelligent_output_path)}", file=sys.stderr)
        print("", file=sys.stderr)
        
        _ensure_parent_dir(intelligent_output_path)
        
        # Get input file size for comparison
        input_size = os.path.getsize(input_path)
        print(f"Input file size: {input_size / 1_000_000:.1f} MB", file=sys.stderr)
        print("", file=sys.stderr)
        
        # Run AI upscaling
        print("Starting AI upscaling (this may take several minutes)...", file=sys.stderr)
        import time
        start_time = time.time()
        
        upscale(
            input_path=input_path,
            output_path=intelligent_output_path,
            width=width,
            height=height,
            scale=scale,
        )
        
        elapsed_time = time.time() - start_time
        print("", file=sys.stderr)
        print(f"AI upscaling completed in {elapsed_time:.1f} seconds ({elapsed_time/60:.1f} minutes)", file=sys.stderr)
        print("", file=sys.stderr)
        
        # Verify the output
        print("Verifying upscaled output...", file=sys.stderr)
        success, verification = _verify_upscaled_output(
            intelligent_output_path, 
            expected_height=target_height,
            input_path=input_path
        )
        
        if not success:
            print(f"✗ VERIFICATION FAILED: {verification.get('error')}", file=sys.stderr)
            print(f"  Output path: {intelligent_output_path}", file=sys.stderr)
            return False
        
        # Log verification results
        print("✓ VERIFICATION PASSED", file=sys.stderr)
        print(f"  File exists: Yes", file=sys.stderr)
        print(f"  File size: {verification['file_size'] / 1_000_000:.1f} MB", file=sys.stderr)
        print(f"  Resolution: {verification['resolution']}", file=sys.stderr)
        print(f"  Codec: {verification['codec']}", file=sys.stderr)
        if verification.get('duration'):
            print(f"  Duration: {verification['duration']:.1f} seconds", file=sys.stderr)
        print(f"  Location: {intelligent_output_path}", file=sys.stderr)
        
        # Calculate size increase
        output_size = verification['file_size']
        size_ratio = output_size / input_size
        print(f"  Size ratio: {size_ratio:.2f}x (input: {input_size/1_000_000:.1f} MB → output: {output_size/1_000_000:.1f} MB)", file=sys.stderr)
        
        return True
        
    except NotImplementedError as e:
        print(f"ERROR: Model not implemented: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"ERROR: AI upscaling failed: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return False


def _acquire_lock(lock_path, timeout_seconds=5):
    start = time.time()
    while True:
        try:
            fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.close(fd)
            return True
        except FileExistsError:
            if time.time() - start >= timeout_seconds:
                return False
            time.sleep(0.1)


def _release_lock(lock_path):
    try:
        os.remove(lock_path)
    except FileNotFoundError:
        return


def _dequeue_job(queue_file):
    lock_path = f"{queue_file}.lock"
    if not os.path.exists(queue_file):
        return None

    if not _acquire_lock(lock_path):
        return None

    try:
        with open(queue_file, "r", encoding="utf-8") as handle:
            lines = [line.strip() for line in handle if line.strip()]
        if not lines:
            return None

        job = None
        remaining = []
        for line in lines:
            if job is None:
                try:
                    payload = json.loads(line)
                    input_path = payload.get("input")
                    output_path = payload.get("output")
                    if input_path and output_path:
                        # Extended job info: (input, output, hls_dir, streaming)
                        hls_dir = payload.get("hls_dir")
                        streaming = payload.get("streaming", False)
                        job = (input_path, output_path, hls_dir, streaming)
                        continue
                except json.JSONDecodeError:
                    pass
            remaining.append(line)

        with open(queue_file, "w", encoding="utf-8") as handle:
            for line in remaining:
                handle.write(f"{line}\n")

        return job
    finally:
        _release_lock(lock_path)


def main():
    parser = argparse.ArgumentParser(
        description="Video upscale wrapper using ffmpeg."
    )
    parser.add_argument("input", nargs="?", help="Input video path")
    parser.add_argument("output", nargs="?", help="Output video path")
    parser.add_argument(
        "--width", type=int, default=None, help="Output width (fallback)"
    )
    parser.add_argument(
        "--height", type=int, default=None, help="Output height (fallback)"
    )
    parser.add_argument(
        "--scale", type=float, default=2.0, help="Upscale factor (model only)"
    )
    args = parser.parse_args()

    wait_seconds = int(os.environ.get("SRGAN_WAIT_SECONDS", "-1") or "-1")
    poll_seconds = float(os.environ.get("SRGAN_QUEUE_POLL_SECONDS", "0.2") or "0.2")
    queue_file = os.environ.get("SRGAN_QUEUE_FILE", "/app/cache/queue.jsonl")
    _ensure_parent_dir(queue_file)

    initial_input = args.input or os.environ.get("JELLYFIN_INPUT_PATH") or os.environ.get(
        "INPUT_PATH"
    )
    initial_output = (
        args.output
        or os.environ.get("JELLYFIN_OUTPUT_PATH")
        or os.environ.get("OUTPUT_PATH")
    )
    used_initial = False
    start = time.time()

    while True:
        job = None
        if not used_initial and initial_input and initial_output:
            # Initial job doesn't have streaming metadata
            job = (initial_input, initial_output, None, False)
            used_initial = True
        else:
            job = _dequeue_job(queue_file)

        if not job:
            if wait_seconds > 0 and time.time() - start >= wait_seconds:
                print("Timed out waiting for input/output paths.", file=sys.stderr)
                sys.exit(2)
            time.sleep(poll_seconds)
            continue

        # Unpack job with streaming metadata
        input_path, output_path, hls_dir, streaming = job
        
        # CRITICAL: Validate input is not HLS stream
        input_lower = input_path.lower()
        if input_lower.endswith('.m3u8') or input_lower.endswith('.m3u') or '/hls/' in input_lower:
            print(f"ERROR: HLS stream inputs are not supported: {input_path}", file=sys.stderr)
            print(f"Only raw video files (MKV, MP4, AVI, etc.) can be upscaled", file=sys.stderr)
            continue
        
        # Reject HLS segment files (more specific check)
        # HLS segments have patterns like segment_NNN.ts, seg_NNN.ts, or are in /hls/ directories
        if input_lower.endswith('.ts'):
            basename = os.path.basename(input_lower)
            normalized_path = input_lower.replace('\\', '/')
            # Check if it's actually an HLS segment (not just any .ts file)
            if ('segment_' in basename or 
                'seg_' in basename or 
                'chunk_' in basename or
                '/hls/' in normalized_path or
                '/segments/' in normalized_path):
                print(f"ERROR: HLS segment files cannot be upscaled: {input_path}", file=sys.stderr)
                continue
        
        if not os.path.exists(input_path):
            print(f"ERROR: Input file does not exist: {input_path}", file=sys.stderr)
            continue
        
        print("=" * 80, file=sys.stderr)
        print(f"AI Upscaling Job", file=sys.stderr)
        print("=" * 80, file=sys.stderr)
        print(f"Input:  {input_path}", file=sys.stderr)
        print(f"Output: {output_path}", file=sys.stderr)
        print("", file=sys.stderr)

        # AI model upscaling is MANDATORY
        enable_model = os.environ.get("SRGAN_ENABLE", "1") == "1"  # Default to enabled
        
        if not enable_model:
            print("ERROR: AI upscaling is disabled (SRGAN_ENABLE=0)", file=sys.stderr)
            print("AI upscaling must be enabled. Set SRGAN_ENABLE=1", file=sys.stderr)
            print("FFmpeg-only upscaling is not supported in this mode.", file=sys.stderr)
            continue
        
        # Try AI model upscaling
        print("Starting AI upscaling with SRGAN model...", file=sys.stderr)
        used_model = _try_model(
            input_path, output_path, args.width, args.height, args.scale
        )
        
        if not used_model:
            print("", file=sys.stderr)
            print("=" * 80, file=sys.stderr)
            print("ERROR: AI model upscaling failed!", file=sys.stderr)
            print("=" * 80, file=sys.stderr)
            print("Possible reasons:", file=sys.stderr)
            print("  1. Model file not found (check SRGAN_MODEL_PATH)", file=sys.stderr)
            print("  2. Model file is corrupted", file=sys.stderr)
            print("  3. GPU memory exhausted", file=sys.stderr)
            print("  4. CUDA/PyTorch error", file=sys.stderr)
            print("", file=sys.stderr)
            print("Check logs above for specific error messages.", file=sys.stderr)
            print("", file=sys.stderr)
            print("To debug:", file=sys.stderr)
            print("  docker logs srgan-upscaler", file=sys.stderr)
            print("  docker exec srgan-upscaler ls -lh /app/models/", file=sys.stderr)
            print("  docker exec srgan-upscaler nvidia-smi", file=sys.stderr)
            print("=" * 80, file=sys.stderr)
            continue
        
        print("", file=sys.stderr)
        print("=" * 80, file=sys.stderr)
        print("✓✓✓ AI UPSCALING SUCCESSFULLY COMPLETED ✓✓✓", file=sys.stderr)
        print("=" * 80, file=sys.stderr)
        print("", file=sys.stderr)
        print("Summary:", file=sys.stderr)
        print(f"  • Input processed: {os.path.basename(input_path)}", file=sys.stderr)
        print(f"  • AI model used: SRGAN", file=sys.stderr)
        print(f"  • Output verified: Yes (valid video file)", file=sys.stderr)
        print(f"  • Ready for playback: Yes", file=sys.stderr)
        print("", file=sys.stderr)
        print("The upscaled file is now available in your media library!", file=sys.stderr)
        print("=" * 80, file=sys.stderr)
        print("", file=sys.stderr)


if __name__ == "__main__":
    main()
