# Real-Time Streaming Upscaling Implementation Plan

## Overview

Enable on-the-fly upscaling where Jellyfin starts playing upscaled content while the video is still being processed, then saves the final result for future playback.

## Current Architecture Problems

### Batch Processing Limitations

**Current workflow:**
1. ✅ Webhook triggers on playback start
2. ✅ Job queued for processing
3. ❌ **Entire file must finish processing before playback**
4. ❌ **User watches original quality**
5. ❌ **Must manually switch to upscaled file later**

**Current code:**
```python
# watchdog.py - Queues job
output_file = os.path.join(upscaled_dir, f"{base_name}.ts")
payload = json.dumps({"input": input_file, "output": output_file})

# srgan_pipeline.py - Processes entire file
subprocess.check_call(["ffmpeg", "-i", input_path, ..., output_path])
```

**Problem:** FFmpeg processes the entire video before completing. No streaming output.

## Solution: HLS (HTTP Live Streaming)

### What is HLS?

HLS breaks video into small segments (2-10 seconds each) and creates a playlist:

```
stream.m3u8          (playlist file)
├── segment_0.ts     (0-10s)
├── segment_1.ts     (10-20s)
├── segment_2.ts     (20-30s)
└── ...
```

**Key benefits:**
- ✅ Segments available immediately as they're created
- ✅ Jellyfin natively supports HLS playback
- ✅ Can play while processing continues
- ✅ Adaptive quality switching

### Architecture Changes

```
┌─────────────┐
│  User plays │
│   video     │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  Webhook trigger    │
│  (watchdog.py)      │
└──────┬──────────────┘
       │
       ├──────────────────────────────────┐
       ▼                                  ▼
┌─────────────────┐              ┌──────────────────┐
│ Start upscaling │              │ Return HLS URL   │
│ with HLS output │              │ to Jellyfin      │
│                 │              │ (for redirect)   │
└────┬────────────┘              └──────────────────┘
     │
     ├─────────────┬─────────────┐
     ▼             ▼             ▼
┌─────────┐  ┌──────────┐  ┌─────────┐
│Generate │  │ Generate │  │  Save   │
│segment_0│  │segment_1 │  │ final   │
└────┬────┘  └────┬─────┘  │ .mp4    │
     │            │         └─────────┘
     ▼            ▼
   User plays segment_0
   while segment_1 generates
```

## Implementation Components

### 1. Enhanced FFmpeg Pipeline

**Dual Output: HLS Stream + Final File**

Use FFmpeg's `tee` muxer to output to both HLS and a final file:

```bash
ffmpeg -i input.mkv \
  # Hardware acceleration
  -hwaccel cuda \
  -hwaccel_output_format cuda \
  \
  # Video encoding
  -c:v hevc_nvenc \
  -preset p4 \
  -crf 18 \
  \
  # Audio passthrough
  -c:a copy \
  \
  # Dual output: HLS + final file
  -f tee \
  -map 0:v -map 0:a \
  "[f=hls:hls_time=6:hls_list_size=10:hls_flags=delete_segments+append_list]stream.m3u8|\
   [f=mpegts]final.ts"
```

**Key parameters:**
- `hls_time=6` - 6 second segments (balance between latency and overhead)
- `hls_list_size=10` - Keep 10 segments in playlist (rolling window)
- `hls_flags=delete_segments` - Delete old segments to save space
- `hls_flags=append_list` - Keep adding to playlist as we go

### 2. Modified srgan_pipeline.py

**Add streaming mode:**

```python
def _run_ffmpeg_streaming(input_path, hls_dir, output_path, width, height):
    """
    Process video with dual output:
    1. HLS stream for immediate playback
    2. Final file for permanent storage
    """
    _ensure_parent_dir(hls_dir)
    _ensure_parent_dir(output_path)

    # HLS playlist path
    hls_playlist = os.path.join(hls_dir, "stream.m3u8")

    # Video filter
    if width and height:
        vf = f"scale={width}:{height}:flags=lanczos"
    else:
        vf = "scale=iw*2:ih*2:flags=lanczos"  # 2x upscale

    hwaccel = os.environ.get("SRGAN_FFMPEG_HWACCEL", "0") == "1"
    encoder = os.environ.get("SRGAN_FFMPEG_ENCODER", "hevc_nvenc")
    preset = os.environ.get("SRGAN_FFMPEG_PRESET", "p4")

    input_opts = []
    if hwaccel:
        input_opts.extend(["-hwaccel", "cuda"])

    # HLS settings
    hls_time = int(os.environ.get("HLS_SEGMENT_TIME", "6"))
    hls_list_size = int(os.environ.get("HLS_LIST_SIZE", "10"))

    cmd = [
        "ffmpeg",
        "-y",
        *input_opts,
        "-i", input_path,
        "-vf", vf,
        "-c:v", encoder,
        "-preset", preset,
        "-crf", "18",
        "-c:a", "copy",
        "-f", "tee",
        "-map", "0:v",
        "-map", "0:a",
        f"[f=hls:hls_time={hls_time}:hls_list_size={hls_list_size}:"
        f"hls_flags=delete_segments+append_list]{hls_playlist}|"
        f"[f=mpegts]{output_path}"
    ]

    # Run asynchronously (don't wait for completion)
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    return process, hls_playlist
```

### 3. Enhanced watchdog.py

**Return HLS URL instead of queueing:**

```python
@app.route("/upscale-trigger", methods=["POST"])
def handle_play():
    """Handle webhook with immediate HLS response."""
    try:
        data = request.json or {}
        input_file = data.get("Item", {}).get("Path")

        if not input_file or not os.path.exists(input_file):
            return jsonify({"status": "error"}), 404

        # Create HLS directory
        base_name = os.path.splitext(os.path.basename(input_file))[0]
        hls_dir = os.path.join("/data/upscaled/hls", base_name)
        output_file = os.path.join("/data/upscaled", f"{base_name}.ts")

        os.makedirs(hls_dir, exist_ok=True)

        # Check if already exists
        if os.path.exists(output_file):
            return jsonify({
                "status": "exists",
                "file": output_file
            }), 200

        # Start upscaling with HLS output
        logger.info(f"Starting HLS upscaling: {input_file}")

        # Add to queue with HLS metadata
        payload = json.dumps({
            "input": input_file,
            "output": output_file,
            "hls_dir": hls_dir,
            "streaming": True
        })

        queue_file = os.environ.get("SRGAN_QUEUE_FILE", "./cache/queue.jsonl")
        os.makedirs(os.path.dirname(queue_file), exist_ok=True)

        with open(queue_file, "a", encoding="utf-8") as f:
            f.write(f"{payload}\n")

        # Start container
        subprocess.run(
            ["docker", "compose", "up", "-d", "srgan-upscaler"],
            capture_output=True,
            timeout=30
        )

        # Return HLS URL immediately
        hls_url = f"http://YOUR_SERVER_IP:8080/hls/{base_name}/stream.m3u8"

        logger.info(f"✓ HLS stream will be available at: {hls_url}")

        return jsonify({
            "status": "streaming",
            "message": "HLS upscaling started",
            "hls_url": hls_url,
            "final_file": output_file,
            "estimated_delay": "10-15 seconds"
        }), 200

    except Exception as e:
        logger.exception(f"Error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
```

### 4. HLS File Server

**Add nginx or Python HTTP server to serve HLS segments:**

**Option A: nginx (Recommended)**

```yaml
# docker-compose.yml
services:
  hls-server:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - /data/upscaled/hls:/usr/share/nginx/html/hls:ro
    restart: unless-stopped
```

**nginx.conf:**
```nginx
server {
    listen 80;

    location /hls {
        alias /usr/share/nginx/html/hls;

        # CORS headers for cross-origin playback
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Cache-Control "no-cache";

        # HLS MIME types
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }
}
```

**Option B: Python Flask server** (simpler, no nginx needed)

```python
# hls_server.py
from flask import Flask, send_from_directory
import os

app = Flask(__name__)
HLS_DIR = "/data/upscaled/hls"

@app.route('/hls/<path:filename>')
def serve_hls(filename):
    """Serve HLS playlist and segments."""
    return send_from_directory(
        HLS_DIR,
        filename,
        mimetype='application/vnd.apple.mpegurl' if filename.endswith('.m3u8')
                 else 'video/mp2t'
    )

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
```

### 5. Jellyfin Integration

**Option A: Plugin Redirect (Most Seamless)**

Create a Jellyfin plugin that intercepts playback and redirects to HLS:

```csharp
// PluginApiController.cs
[HttpPost("redirect-playback")]
public async Task<IActionResult> RedirectPlayback([FromBody] PlaybackRequest request)
{
    // Get HLS URL from watchdog
    var response = await _httpClient.PostAsync(
        "http://watchdog:5000/upscale-trigger",
        new StringContent(JsonSerializer.Serialize(request))
    );

    var result = await response.Content.ReadAsStringAsync();
    var hlsInfo = JsonSerializer.Deserialize<HlsResponse>(result);

    if (hlsInfo.Status == "streaming")
    {
        // Redirect player to HLS stream
        return Redirect(hlsInfo.HlsUrl);
    }

    // Fallback to original file
    return Ok(new { useOriginal = true });
}
```

**Option B: Manual Playlist Entry**

After webhook triggers:
1. Add HLS stream as a new library entry
2. User sees both original and "4K Upscaling" versions
3. Switch to upscaled version after delay

**Option C: External Player**

Use external player like VLC or MPV that supports HLS:
```bash
mpv http://server:8080/hls/movie/stream.m3u8
```

### 6. Monitoring & Cleanup

**Monitor upscaling progress:**

```python
# monitor_hls.py
import os
import time

def monitor_hls_progress(hls_dir, total_duration):
    """Monitor HLS generation progress."""
    while True:
        # Count segments
        segments = [f for f in os.listdir(hls_dir) if f.endswith('.ts')]
        current_duration = len(segments) * 6  # 6 second segments

        progress = (current_duration / total_duration) * 100
        print(f"Progress: {progress:.1f}% ({current_duration}s / {total_duration}s)")

        if current_duration >= total_duration:
            print("✓ Upscaling complete!")
            break

        time.sleep(5)
```

**Cleanup old HLS segments:**

```python
# cleanup_hls.py
import os
import time
import shutil

def cleanup_old_hls(hls_dir, max_age_hours=24):
    """Delete HLS segments older than max_age_hours."""
    current_time = time.time()
    max_age_seconds = max_age_hours * 3600

    for root, dirs, files in os.walk(hls_dir):
        for dir_name in dirs:
            dir_path = os.path.join(root, dir_name)
            mtime = os.path.getmtime(dir_path)

            if current_time - mtime > max_age_seconds:
                print(f"Removing old HLS directory: {dir_path}")
                shutil.rmtree(dir_path)
```

## Workflow Example

### Step-by-Step User Experience

**1. User clicks play on "Movie.mkv" in Jellyfin**

**2. Webhook fires → watchdog.py receives event**
```json
{
  "Item": {
    "Path": "/data/movies/Movie.mkv",
    "Name": "Movie"
  }
}
```

**3. Watchdog starts upscaling + returns HLS info**
```bash
# FFmpeg starts in background
ffmpeg -i Movie.mkv [...] stream.m3u8|final.ts

# HLS files created:
/data/upscaled/hls/Movie/stream.m3u8
/data/upscaled/hls/Movie/segment_0.ts
/data/upscaled/hls/Movie/segment_1.ts
...
```

**4. After 10-15 seconds, switch to HLS stream**
```
Original playback: Movie.mkv (1080p)
                    ↓
             [10 second delay]
                    ↓
Switch to: http://server:8080/hls/Movie/stream.m3u8 (4K)
```

**5. Continue playing upscaled content as it generates**
```
Playing segment_3.ts while segment_4.ts is being created
```

**6. After playback ends, final file saved**
```
/data/upscaled/Movie.ts (complete 4K file)
```

**7. Next playback uses saved file directly**
```
No upscaling needed - play /data/upscaled/Movie.ts
```

## Performance Considerations

### Latency Analysis

**Initial delay before HLS becomes available:**
- Segment creation time: ~6 seconds (per segment)
- First playable moment: ~10-15 seconds
- Buffer requirement: 2-3 segments (~12-18 seconds)

**Upscaling must be >= 1.0x real-time:**
- If movie is 24 FPS, must process >= 24 FPS
- Use `audit_performance.py` to monitor
- If too slow, reduce quality or resolution

### Storage Requirements

**During streaming:**
- HLS segments: ~10 segments × file size / segments
- Example: 10GB movie → ~100MB HLS buffer

**After completion:**
- HLS segments deleted
- Only final file remains
- Same storage as current implementation

### Network Requirements

**Bandwidth:**
- 4K HEVC: ~15-25 Mbps
- Local network: No problem
- Internet streaming: Need good upload speed

## Implementation Phases

### Phase 1: Basic HLS Output (Minimal Changes)

**Changes needed:**
1. ✅ Modify `srgan_pipeline.py` to use `tee` muxer
2. ✅ Output to HLS directory + final file
3. ✅ Add simple HTTP server for HLS files
4. ✅ Test with VLC/MPV external player

**Testing:**
```bash
# Start upscaling
docker compose run srgan-upscaler /data/movies/test.mkv /data/upscaled/test.ts

# Play HLS stream while processing
mpv http://localhost:8080/hls/test/stream.m3u8
```

### Phase 2: Watchdog Integration

**Changes needed:**
1. ✅ Modify `watchdog.py` to pass HLS metadata
2. ✅ Return HLS URL in webhook response
3. ✅ Add progress monitoring endpoint
4. ✅ Add HLS cleanup job

### Phase 3: Jellyfin Plugin Integration

**Changes needed:**
1. ✅ Create C# plugin for playback redirection
2. ✅ Add UI for "Use upscaled stream" option
3. ✅ Handle fallback to original on error
4. ✅ Show progress indicator

### Phase 4: Advanced Features

**Optional enhancements:**
1. ✅ Adaptive bitrate (multiple quality levels)
2. ✅ Resume from where upscaling left off
3. ✅ Pre-upscale popular content
4. ✅ User preferences (auto-switch, quality)

## Testing Plan

### Test 1: Basic HLS Generation

```bash
# Start upscaling with HLS output
docker compose run srgan-upscaler \
  --streaming \
  /data/movies/test.mkv \
  /data/upscaled/test.ts

# Verify HLS files created
ls /data/upscaled/hls/test/
# Should show: stream.m3u8, segment_0.ts, segment_1.ts, ...
```

### Test 2: Play HLS While Processing

```bash
# Terminal 1: Start upscaling
docker compose run srgan-upscaler [...]

# Terminal 2: Wait 15 seconds, then play
sleep 15
mpv http://localhost:8080/hls/test/stream.m3u8

# Should play upscaled content immediately
```

### Test 3: Monitor Performance

```bash
# Check real-time multiplier
python3 scripts/audit_performance.py --output /data/upscaled/test.ts

# Must be >= 1.0x for real-time streaming
```

### Test 4: End-to-End with Jellyfin

```bash
# 1. Play video in Jellyfin
# 2. Check webhook received
curl http://localhost:5000/health

# 3. Verify HLS stream available
curl http://localhost:8080/hls/movie/stream.m3u8

# 4. Check final file created
ls -lh /data/upscaled/movie.ts
```

## Limitations & Caveats

### Technical Limitations

**1. Requires Real-Time Performance**
- Must process >= 1.0x real-time
- If GPU is too slow, playback will stutter
- Solution: Lower resolution or quality

**2. Initial Delay**
- 10-15 second delay before HLS available
- User sees original quality briefly
- Can't be eliminated (need buffer)

**3. Storage Overhead**
- HLS segments use extra disk space during processing
- Need ~100-500MB free per stream
- Cleaned up after completion

**4. Jellyfin Integration Complexity**
- No native "redirect to HLS" feature
- Need plugin or manual switching
- May require user action

### User Experience Considerations

**What users will notice:**

**Good:**
- ✅ Upscaled content available much faster
- ✅ Can start watching sooner
- ✅ Seamless quality transition (if plugin works)

**Bad:**
- ⚠️ Initial 10-15 second delay
- ⚠️ Quality switch may be noticeable
- ⚠️ May need manual switching (without plugin)

### When This Works Best

**Ideal scenarios:**
- ✅ Long movies (>1 hour) where delay is negligible
- ✅ Powerful GPU (>= 1.5x real-time performance)
- ✅ Local network playback
- ✅ Users willing to wait 15 seconds for 4K

**Not ideal for:**
- ❌ Short videos (<10 minutes)
- ❌ Slow GPU (< 1.0x real-time)
- ❌ Remote internet streaming
- ❌ Users expecting instant 4K

## Alternative: Hybrid Approach

### Smart Switching Based on File Status

```python
@app.route("/upscale-trigger", methods=["POST"])
def handle_play():
    """Hybrid: Use existing file if available, otherwise stream."""

    input_file = data.get("Item", {}).get("Path")
    output_file = get_output_path(input_file)

    # Check if already upscaled
    if os.path.exists(output_file):
        return jsonify({
            "status": "use_existing",
            "file": output_file,
            "message": "Playing pre-upscaled version"
        })

    # Check if currently being upscaled
    hls_playlist = get_hls_path(input_file)
    if os.path.exists(hls_playlist):
        return jsonify({
            "status": "streaming",
            "hls_url": get_hls_url(input_file),
            "message": "Upscaling in progress - switch to HLS"
        })

    # Start new upscaling job
    start_hls_upscaling(input_file, output_file, hls_playlist)

    return jsonify({
        "status": "started",
        "message": "Upscaling started - check back in 15s",
        "check_url": f"/status/{job_id}"
    })
```

## Recommendation

### Start with Phase 1

**Implement basic HLS output first:**

1. Modify `srgan_pipeline.py` for HLS support
2. Add nginx/Flask HLS server
3. Test with external player (VLC/MPV)
4. Verify performance is >= 1.0x real-time

**Then decide:**
- If performance is good → Continue to Phase 2-3
- If performance is borderline → Stick with batch processing
- If GPU is too slow → Not feasible

### Would you like me to implement Phase 1?

I can create:
1. ✅ Modified `srgan_pipeline.py` with HLS support
2. ✅ HLS server (nginx or Flask)
3. ✅ Test scripts
4. ✅ Documentation

This will let you test if real-time streaming is viable on your hardware before committing to full Jellyfin integration.

**Ready to proceed?**
