#!/usr/bin/env python3
"""
SRGAN Watchdog - API-Based Version

Instead of relying on webhook {{Path}} variable, this version:
1. Receives webhook notification (any payload)
2. Queries Jellyfin /Sessions API to get currently playing item
3. Extracts file path from NowPlayingItem
4. Queues the upscaling job

This is more reliable as it uses Jellyfin's official API.
"""

from flask import Flask, request, jsonify
import json
import os
import subprocess
import logging
import time
import requests
from datetime import datetime

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Jellyfin API Configuration
JELLYFIN_URL = os.environ.get("JELLYFIN_URL", "http://localhost:8096")
JELLYFIN_API_KEY = os.environ.get("JELLYFIN_API_KEY", "")

# Cache to prevent duplicate processing
processed_items = {}
CACHE_DURATION = 300  # 5 minutes


def get_jellyfin_sessions():
    """
    Query Jellyfin /Sessions API to get currently active sessions.
    
    Returns list of sessions with NowPlayingItem details.
    Requires JELLYFIN_API_KEY to be set.
    """
    if not JELLYFIN_API_KEY:
        logger.error("JELLYFIN_API_KEY not set!")
        logger.error("Set it in environment: export JELLYFIN_API_KEY=your_api_key")
        logger.error("")
        logger.error("To get API key:")
        logger.error("  1. Jellyfin Dashboard → API Keys")
        logger.error("  2. Click + to create new key")
        logger.error("  3. Name: SRGAN Watchdog")
        logger.error("  4. Copy the key")
        return None
    
    url = f"{JELLYFIN_URL}/Sessions"
    headers = {
        "X-Emby-Token": JELLYFIN_API_KEY
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=5)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to query Jellyfin API: {e}")
        return None


def extract_playing_items():
    """
    Get all currently playing items from active sessions.
    
    Returns list of dicts with:
    - path: File path
    - name: Item name
    - item_id: Jellyfin item ID
    - user: Username
    - session_id: Session ID
    """
    sessions = get_jellyfin_sessions()
    if not sessions:
        return []
    
    playing_items = []
    
    for session in sessions:
        # Check if this session has a currently playing item
        now_playing = session.get("NowPlayingItem")
        if not now_playing:
            continue
        
        # Get playstate
        play_state = session.get("PlayState", {})
        is_paused = play_state.get("IsPaused", False)
        
        # Only process if actually playing (not paused)
        if is_paused:
            logger.debug(f"Session {session.get('Id')} is paused, skipping")
            continue
        
        # Extract file path from NowPlayingItem
        # The path is in: NowPlayingItem.Path or NowPlayingItem.MediaSources[0].Path
        file_path = now_playing.get("Path")
        
        if not file_path:
            # Try MediaSources
            media_sources = now_playing.get("MediaSources", [])
            if media_sources:
                file_path = media_sources[0].get("Path")
        
        if not file_path:
            logger.warning(f"No file path found for item {now_playing.get('Name')}")
            continue
        
        # Extract metadata
        item = {
            "path": file_path,
            "name": now_playing.get("Name", "Unknown"),
            "item_id": now_playing.get("Id"),
            "item_type": now_playing.get("Type"),
            "user": session.get("UserName", "Unknown"),
            "session_id": session.get("Id"),
            "client": session.get("Client", "Unknown")
        }
        
        playing_items.append(item)
        logger.info(f"Found playing item: {item['name']} ({item['path']})")
    
    return playing_items


def is_recently_processed(item_id):
    """Check if item was recently processed (prevent duplicates)."""
    if item_id in processed_items:
        last_time = processed_items[item_id]
        if time.time() - last_time < CACHE_DURATION:
            return True
    return False


def mark_processed(item_id):
    """Mark item as processed with timestamp."""
    processed_items[item_id] = time.time()
    
    # Clean old entries
    current_time = time.time()
    expired = [k for k, v in processed_items.items() if current_time - v > CACHE_DURATION]
    for k in expired:
        del processed_items[k]


def queue_upscaling_job(item):
    """
    Queue an upscaling job for the given item.
    
    Args:
        item: Dict with path, name, item_id, etc.
    
    Returns:
        tuple: (success: bool, response_data: dict)
    """
    input_file = item["path"]
    
    # Check if file exists
    if not os.path.exists(input_file):
        logger.error(f"ERROR: Input file does not exist: {input_file}")
        return False, {"error": "File not found on host"}
    
    logger.info(f"✓ File exists: {input_file}")
    
    # Setup output directory and file
    upscaled_dir = os.environ.get("UPSCALED_DIR", "/mnt/media/upscaled")
    base_name = os.path.splitext(os.path.basename(input_file))[0]
    output_file = os.path.join(upscaled_dir, f"{base_name}.ts")
    
    # Check if already upscaled
    if os.path.exists(output_file):
        logger.info(f"✓ Output file already exists: {output_file}")
        return True, {
            "status": "ready",
            "message": "File already upscaled",
            "file": output_file
        }
    
    # Check if streaming mode is enabled
    enable_streaming = os.environ.get("ENABLE_HLS_STREAMING", "1") == "1"
    
    if enable_streaming:
        # HLS streaming mode
        hls_dir = os.path.join(upscaled_dir, "hls", base_name)
        hls_playlist = os.path.join(hls_dir, "stream.m3u8")
        
        logger.info(f"Streaming mode enabled")
        logger.info(f"HLS directory: {hls_dir}")
        
        # Create HLS directory
        os.makedirs(hls_dir, exist_ok=True)
        
        # Check if HLS stream already in progress
        if os.path.exists(hls_playlist):
            logger.info(f"⚠ HLS stream already in progress: {hls_playlist}")
            
            hls_server_host = os.environ.get("HLS_SERVER_HOST", "localhost")
            hls_server_port = os.environ.get("HLS_SERVER_PORT", "8080")
            hls_url = f"http://{hls_server_host}:{hls_server_port}/hls/{base_name}/stream.m3u8"
            
            return True, {
                "status": "streaming",
                "message": "Upscaling already in progress",
                "hls_url": hls_url
            }
        
        # Add to queue
        queue_file = os.environ.get("SRGAN_QUEUE_FILE", "./cache/queue.jsonl")
        os.makedirs(os.path.dirname(queue_file), exist_ok=True)
        
        payload = json.dumps({
            "input": input_file,
            "output": output_file,
            "hls_dir": hls_dir,
            "streaming": True,
            "item_id": item.get("item_id"),
            "item_name": item.get("name"),
            "user": item.get("user")
        })
        
        with open(queue_file, "a", encoding="utf-8") as handle:
            handle.write(f"{payload}\n")
        
        logger.info(f"✓ Streaming job added to queue")
        logger.info(f"  Input:      {input_file}")
        logger.info(f"  Output:     {output_file}")
        logger.info(f"  HLS dir:    {hls_dir}")
        logger.info(f"  Item:       {item.get('name')}")
        logger.info(f"  User:       {item.get('user')}")
        
        # Start the upscaler container
        logger.info("Starting srgan-upscaler container...")
        try:
            result = subprocess.run(
                ["docker", "compose", "up", "-d", "srgan-upscaler"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode != 0:
                logger.error(f"Docker compose error: {result.stderr}")
                return False, {"error": f"Docker error: {result.stderr}"}
            
            logger.info("✓ Docker compose command successful")
        except subprocess.TimeoutExpired:
            logger.error("Docker compose command timed out")
        except FileNotFoundError:
            logger.error("ERROR: 'docker' command not found")
            return False, {"error": "Docker not found"}
        
        # Get HLS URL
        hls_server_host = os.environ.get("HLS_SERVER_HOST", "localhost")
        hls_server_port = os.environ.get("HLS_SERVER_PORT", "8080")
        hls_url = f"http://{hls_server_host}:{hls_server_port}/hls/{base_name}/stream.m3u8"
        
        return True, {
            "status": "queued",
            "message": "Upscaling job queued successfully",
            "hls_url": hls_url,
            "input": input_file,
            "output": output_file,
            "hls_dir": hls_dir
        }
    
    # Batch mode (non-streaming)
    logger.error("Batch mode not yet implemented in API version")
    return False, {"error": "Batch mode not implemented"}


@app.route("/upscale-trigger", methods=["POST"])
def handle_webhook():
    """
    Handle webhook trigger from Jellyfin.
    
    Instead of using {{Path}} from payload, we:
    1. Receive the webhook (any payload)
    2. Query Jellyfin API /Sessions
    3. Get currently playing items with file paths
    4. Queue upscaling jobs
    
    This is more reliable than depending on webhook template variables.
    """
    try:
        logger.info("=" * 80)
        logger.info("Webhook received!")
        
        # Log payload for debugging (but don't rely on it)
        try:
            data = request.json if request.is_json else {}
            logger.info(f"Webhook payload: {json.dumps(data, indent=2)}")
        except:
            logger.warning("Could not parse webhook payload (not important)")
        
        # Query Jellyfin API for currently playing items
        logger.info("Querying Jellyfin API for currently playing items...")
        playing_items = extract_playing_items()
        
        if not playing_items:
            logger.warning("No currently playing items found")
            return jsonify({
                "status": "info",
                "message": "No currently playing items found",
                "note": "This is normal if playback hasn't started yet or is paused"
            }), 200
        
        logger.info(f"Found {len(playing_items)} playing item(s)")
        
        # Process each playing item
        results = []
        for item in playing_items:
            item_id = item.get("item_id")
            
            # Check if already processed recently
            if is_recently_processed(item_id):
                logger.info(f"Item {item['name']} already processed recently, skipping")
                results.append({
                    "item": item["name"],
                    "status": "skipped",
                    "reason": "recently_processed"
                })
                continue
            
            # Queue the job
            success, response_data = queue_upscaling_job(item)
            
            if success:
                mark_processed(item_id)
                results.append({
                    "item": item["name"],
                    "status": "success",
                    "data": response_data
                })
            else:
                results.append({
                    "item": item["name"],
                    "status": "error",
                    "data": response_data
                })
        
        logger.info("=" * 80)
        
        return jsonify({
            "status": "success",
            "message": f"Processed {len(playing_items)} item(s)",
            "results": results
        }), 200
        
    except Exception as e:
        logger.exception("Unexpected error in webhook handler")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route("/status", methods=["GET"])
def status():
    """Health check and status endpoint."""
    # Check Jellyfin connectivity
    jellyfin_ok = False
    if JELLYFIN_API_KEY:
        sessions = get_jellyfin_sessions()
        jellyfin_ok = sessions is not None
    
    return jsonify({
        "status": "running",
        "jellyfin_url": JELLYFIN_URL,
        "jellyfin_api_configured": bool(JELLYFIN_API_KEY),
        "jellyfin_reachable": jellyfin_ok,
        "queue_file": os.environ.get("SRGAN_QUEUE_FILE", "./cache/queue.jsonl"),
        "upscaled_dir": os.environ.get("UPSCALED_DIR", "/mnt/media/upscaled"),
        "streaming_enabled": os.environ.get("ENABLE_HLS_STREAMING", "1") == "1"
    }), 200


@app.route("/sessions", methods=["GET"])
def get_sessions():
    """Debug endpoint to view current Jellyfin sessions."""
    sessions = get_jellyfin_sessions()
    if sessions is None:
        return jsonify({"error": "Could not fetch sessions"}), 500
    
    return jsonify(sessions), 200


@app.route("/playing", methods=["GET"])
def get_playing():
    """Debug endpoint to view currently playing items."""
    items = extract_playing_items()
    return jsonify({
        "count": len(items),
        "items": items
    }), 200


if __name__ == "__main__":
    logger.info("=" * 80)
    logger.info("SRGAN Watchdog - API-Based Version")
    logger.info("=" * 80)
    logger.info("")
    logger.info("This version uses Jellyfin API instead of webhook {{Path}} variable")
    logger.info("")
    logger.info("Configuration:")
    logger.info(f"  Jellyfin URL: {JELLYFIN_URL}")
    logger.info(f"  API Key: {'✓ Set' if JELLYFIN_API_KEY else '✗ NOT SET'}")
    logger.info(f"  Queue file: {os.environ.get('SRGAN_QUEUE_FILE', './cache/queue.jsonl')}")
    logger.info(f"  Output dir: {os.environ.get('UPSCALED_DIR', '/mnt/media/upscaled')}")
    logger.info(f"  HLS streaming: {'Enabled' if os.environ.get('ENABLE_HLS_STREAMING', '1') == '1' else 'Disabled'}")
    logger.info("")
    
    if not JELLYFIN_API_KEY:
        logger.error("⚠️  JELLYFIN_API_KEY is not set!")
        logger.error("")
        logger.error("To create an API key:")
        logger.error("  1. Open Jellyfin Dashboard")
        logger.error("  2. Go to: API Keys (under Advanced)")
        logger.error("  3. Click '+' to add new key")
        logger.error("  4. Name: SRGAN Watchdog")
        logger.error("  5. Copy the generated key")
        logger.error("  6. Set environment: export JELLYFIN_API_KEY=your_key")
        logger.error("")
        logger.error("Then restart this service.")
        logger.error("")
    
    logger.info("Starting Flask server on 0.0.0.0:5432...")
    logger.info("=" * 80)
    logger.info("")
    
    # Run Flask app
    app.run(host="0.0.0.0", port=5432, debug=False)
