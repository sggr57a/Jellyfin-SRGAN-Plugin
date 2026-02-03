# Webhook to Container Flow - Complete Architecture

## Overview

The system uses a **queue-based architecture** where:
1. Jellyfin sends webhook → Watchdog (Flask app)
2. Watchdog validates and writes to queue file
3. Container polls queue file and processes videos

---

## Component Architecture

```
┌─────────────────┐
│    Jellyfin     │
│  (on host)      │
└────────┬────────┘
         │ HTTP POST Webhook
         │ {Path: "/media/movies/file.mkv"}
         ▼
┌─────────────────────────────────────────┐
│  Watchdog (Flask on Host)               │
│  - Listens on port 5432                 │
│  - Validates webhook payload            │
│  - Checks file exists                   │
│  - Writes to queue.jsonl                │
│  - Starts Docker container              │
└────────┬────────────────────────────────┘
         │ Writes to
         │ /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl
         ▼
┌─────────────────────────────────────────┐
│  Shared Volume (Host)                   │
│  /root/.../cache/queue.jsonl            │
│  ↕ Mounted as /app/cache/queue.jsonl    │
└────────┬────────────────────────────────┘
         │ Container reads from
         ▼
┌─────────────────────────────────────────┐
│  srgan-upscaler Container               │
│  - Polls queue.jsonl every 0.2s         │
│  - Dequeues job                         │
│  - Reads input file from mounted volume │
│  - Processes with FFmpeg + CUDA         │
│  - Writes HLS stream + final output     │
└─────────────────────────────────────────┘
```

---

## Step-by-Step Flow

### 1. Jellyfin Sends Webhook

**When:** User starts playing a video  
**What:** Jellyfin's Webhook Plugin sends HTTP POST to watchdog

```http
POST http://localhost:5432/upscale-trigger
Content-Type: application/json

{
  "Path": "/media/movies/Example.mkv",
  "Name": "Example Movie",
  "ItemType": "Movie",
  "NotificationType": "PlaybackStart"
}
```

**Configuration:**
- Dashboard → Plugins → Webhook
- Add Generic Destination: `http://localhost:5432/upscale-trigger`
- Notification Type: **Playback Start**
- Item Type: **Movie, Episode**
- Template: JSON with `{{Path}}`

---

### 2. Watchdog Receives & Validates

**Process:** `scripts/watchdog.py` (Flask app on host)

```python
@app.route("/upscale-trigger", methods=["POST"])
def handle_play():
    # 1. Parse JSON payload
    data = request.json
    input_file = data.get("Path")  # "/media/movies/Example.mkv"
    
    # 2. Validate path exists on HOST
    if not os.path.exists(input_file):
        return error("File not found on host")
    
    # 3. Setup output paths
    output_file = "/mnt/media/upscaled/Example.ts"
    hls_dir = "/mnt/media/upscaled/hls/Example/"
    
    # 4. Write job to queue file
    queue_file = "./cache/queue.jsonl"
    payload = {
        "input": input_file,
        "output": output_file,
        "hls_dir": hls_dir,
        "streaming": True
    }
    with open(queue_file, "a") as f:
        f.write(json.dumps(payload) + "\n")
    
    # 5. Start container
    subprocess.run(["docker", "compose", "up", "-d", "srgan-upscaler"])
    
    # 6. Return HLS URL to client
    return {"hls_url": "http://localhost:8080/hls/Example/stream.m3u8"}
```

**Queue File Format** (`./cache/queue.jsonl`):
```jsonl
{"input":"/media/movies/Example.mkv","output":"/mnt/media/upscaled/Example.ts","hls_dir":"/mnt/media/upscaled/hls/Example/","streaming":true}
{"input":"/media/tv/Show.mkv","output":"/mnt/media/upscaled/Show.ts","hls_dir":"/mnt/media/upscaled/hls/Show/","streaming":true}
```

---

### 3. Shared Volume (Queue File)

**Host Side:**
```
/root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl
```

**Container Side:**
```
/app/cache/queue.jsonl
```

**Volume Mount** (docker-compose.yml):
```yaml
volumes:
  - ./cache:/app/cache  # Shared queue
```

**Why Queue File?**
- ✅ Simple inter-process communication
- ✅ Persistent (survives container restarts)
- ✅ No network setup needed
- ✅ Human-readable (easy debugging)
- ✅ Append-only (no race conditions)

---

### 4. Container Polls Queue

**Process:** `scripts/srgan_pipeline.py` (runs inside container)

```python
def main():
    queue_file = "/app/cache/queue.jsonl"
    poll_seconds = 0.2  # Check every 200ms
    
    while True:
        # Try to dequeue a job
        job = _dequeue_job(queue_file)
        
        if job:
            input_path, output_path, hls_dir, streaming = job
            
            # Check if container can access the file
            if not os.path.exists(input_path):
                print(f"ERROR: Input file not found: {input_path}")
                continue
            
            # Process the video
            if streaming:
                _run_ffmpeg_streaming(input_path, output_path, hls_dir)
            else:
                _run_ffmpeg(input_path, output_path)
        else:
            # No jobs, wait and poll again
            time.sleep(poll_seconds)
```

**Dequeue Logic:**
```python
def _dequeue_job(queue_file):
    """
    Read first line from queue, delete it, return job.
    JSONL format: one job per line
    """
    if not os.path.exists(queue_file):
        return None
    
    with open(queue_file, "r") as f:
        lines = f.readlines()
    
    if not lines:
        return None
    
    # Get first job
    job_data = json.loads(lines[0])
    
    # Remove first line (dequeue)
    with open(queue_file, "w") as f:
        f.writelines(lines[1:])
    
    return (
        job_data["input"],
        job_data["output"],
        job_data.get("hls_dir"),
        job_data.get("streaming", False)
    )
```

---

### 5. Container Processes Video

**Requirements:**
1. **Input file accessible** via volume mount
2. **Output directory writable** via volume mount
3. **GPU access** for CUDA acceleration

**Volume Mounts Needed:**
```yaml
volumes:
  # INPUT: Container must access same paths as Jellyfin
  - /media:/media:ro              # Read input files
  
  # OUTPUT: Container writes upscaled files
  - /mnt/media/upscaled:/data/upscaled  # Write output
  
  # QUEUE: Shared communication
  - ./cache:/app/cache            # Read/write queue
  
  # MODELS: AI weights
  - ./models:/app/models:ro       # Read model files
```

**Processing:**
```python
def _run_ffmpeg_streaming(input_path, output_path, hls_dir):
    """
    Process video with dual output:
    1. HLS stream (.m3u8 + .ts segments) - real-time playback
    2. Final output file (.ts) - permanent storage
    """
    
    # FFmpeg command with CUDA acceleration
    subprocess.run([
        "ffmpeg",
        "-hwaccel", "cuda",          # GPU decode
        "-i", input_path,            # Input: /media/movies/Example.mkv
        "-vf", "scale=iw*2:ih*2",    # 2x upscale
        "-c:v", "hevc_nvenc",        # GPU encode
        "-preset", "p4",             # Quality preset
        
        # HLS stream output (for real-time playback)
        "-f", "hls",
        "-hls_time", "6",            # 6 second segments
        "-hls_playlist_type", "event",
        f"{hls_dir}/stream.m3u8",    # Playlist
        
        # Final file output
        "-c", "copy",
        output_path                   # /mnt/media/upscaled/Example.ts
    ])
```

---

## Systemd Service (Watchdog)

**Service File:** `/etc/systemd/system/srgan-watchdog.service`

```ini
[Unit]
Description=SRGAN Watchdog Webhook Listener
After=network.target docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/Jellyfin-SRGAN-Plugin
Environment="UPSCALED_DIR=/mnt/media/upscaled"
Environment="SRGAN_QUEUE_FILE=/root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl"
Environment="ENABLE_HLS_STREAMING=1"
Environment="HLS_SERVER_HOST=localhost"
Environment="HLS_SERVER_PORT=8080"
ExecStart=/usr/bin/python3 /root/Jellyfin-SRGAN-Plugin/scripts/watchdog.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Management:**
```bash
# Start watchdog
sudo systemctl start srgan-watchdog

# Check status
sudo systemctl status srgan-watchdog

# View logs
sudo journalctl -u srgan-watchdog -f

# Or if log file is used:
tail -f /var/log/srgan-watchdog.log
```

---

## Docker Container (Upscaler)

**Dockerfile:** Runs srgan_pipeline.py on startup

```dockerfile
FROM nvidia/cuda:12.0-runtime-ubuntu22.04

# Install FFmpeg with NVIDIA support
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-pip

# Copy scripts
COPY scripts/ /app/scripts/
WORKDIR /app

# Container loops, polling queue
CMD ["python3", "/app/scripts/srgan_pipeline.py"]
```

**Environment Variables:**
```yaml
environment:
  - SRGAN_QUEUE_FILE=/app/cache/queue.jsonl
  - SRGAN_QUEUE_POLL_SECONDS=0.2
  - SRGAN_FFMPEG_HWACCEL=1
  - SRGAN_FFMPEG_ENCODER=hevc_nvenc
  - UPSCALED_DIR=/data/upscaled
  - ENABLE_HLS_STREAMING=1
```

---

## Alternative: Static Input (Non-Webhook)

You can also manually queue jobs without Jellyfin:

### Method 1: Direct Queue Write

```bash
# Write job to queue
cat >> /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl << 'EOF'
{"input":"/media/movies/MyVideo.mkv","output":"/mnt/media/upscaled/MyVideo.ts","hls_dir":"/mnt/media/upscaled/hls/MyVideo/","streaming":true}
EOF

# Container will pick it up automatically
```

### Method 2: Environment Variables

```bash
# Run container with direct input (bypasses queue)
docker run \
  -e INPUT_PATH=/media/movies/MyVideo.mkv \
  -e OUTPUT_PATH=/mnt/media/upscaled/MyVideo.ts \
  -v /media:/media:ro \
  -v /mnt/media/upscaled:/data/upscaled \
  --gpus all \
  srgan_live_upscaler:latest
```

### Method 3: API Call to Watchdog

```bash
# Send manual webhook trigger
curl -X POST http://localhost:5432/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "Path": "/media/movies/MyVideo.mkv",
    "Name": "My Video"
  }'
```

---

## Debugging the Flow

### Check Each Step:

#### 1. Webhook Received?
```bash
# Watchdog logs
tail -f /var/log/srgan-watchdog.log

# Should see:
# Webhook received!
# Extracted file path: /media/movies/Example.mkv
```

#### 2. Queue File Written?
```bash
cat /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl

# Should contain:
# {"input":"/media/movies/Example.mkv",...}
```

#### 3. Container Running?
```bash
docker ps | grep srgan-upscaler

# Should show: srgan-upscaler container running
```

#### 4. Container Polling Queue?
```bash
docker logs srgan-upscaler

# Should see:
# Polling queue file: /app/cache/queue.jsonl
# Found job: /media/movies/Example.mkv
```

#### 5. Container Can Access File?
```bash
# Test from container
docker compose exec srgan-upscaler test -f /media/movies/Example.mkv && echo "✓ FILE FOUND"

# Or list files
docker compose exec srgan-upscaler ls -lh /media/movies/
```

#### 6. Processing Started?
```bash
docker logs srgan-upscaler -f

# Should see FFmpeg output:
# Starting upscaling...
# frame=  123 fps= 45 q=-0.0 size=   12345kB time=00:00:05.12
```

#### 7. Output Created?
```bash
# Check HLS stream
ls -lh /mnt/media/upscaled/hls/Example/

# Should contain:
# stream.m3u8
# segment000.ts
# segment001.ts
# ...

# Check final file
ls -lh /mnt/media/upscaled/Example.ts
```

---

## Key Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `watchdog.py` | Flask webhook receiver | Host (systemd service) |
| `srgan_pipeline.py` | Queue polling processor | Container (CMD) |
| `docker-compose.yml` | Container + volumes | Host |
| `queue.jsonl` | Job queue (shared) | Host + Container |
| `Jellyfin.Plugin.Webhook.xml` | Webhook config | `/var/lib/jellyfin/plugins/configurations/` |

---

## Port Reference

| Port | Service | Used For |
|------|---------|----------|
| 5432 | Watchdog (Flask) | Receiving webhooks from Jellyfin |
| 8080 | HLS Server (nginx) | Serving .m3u8 playlists to Jellyfin |
| 8096 | Jellyfin | Main UI |

---

## Summary

**The webhook does NOT go directly to the container.**

Instead:
1. ✅ Jellyfin → Watchdog (host Flask app) via HTTP
2. ✅ Watchdog → Queue file (shared volume) via file write
3. ✅ Queue file → Container (polling) via file read
4. ✅ Container processes video using FFmpeg + CUDA
5. ✅ Output → HLS stream + final file

**Why This Design?**
- Jellyfin can't talk directly to containers (no webhook URL)
- Queue file is simple, reliable inter-process communication
- Watchdog runs on host (has full filesystem access)
- Container is isolated (only sees mounted volumes)
- Clean separation of concerns

**To receive webhooks, the watchdog Flask app must be running on the host!**

```bash
# Ensure watchdog is running
sudo systemctl status srgan-watchdog

# If not:
sudo systemctl start srgan-watchdog
```

🚀 **That's the complete flow from webhook to container!**
