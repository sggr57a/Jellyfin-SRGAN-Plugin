# SRGAN Pipeline - Simple Architecture

## Quick Overview

```
Jellyfin → Watchdog → Queue File → Container → Output
  (web)     (Flask)    (shared)     (Docker)    (HLS)
```

---

## Component Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                         HOST MACHINE                         │
│                                                              │
│  ┌────────────┐         ┌─────────────────┐                │
│  │  Jellyfin  │  HTTP   │  Watchdog       │                │
│  │  :8096     │────────▶│  Flask :5432    │                │
│  │            │ webhook │  (systemd)      │                │
│  └────────────┘         └────────┬────────┘                │
│                                  │ writes                   │
│                                  ▼                           │
│                         ┌─────────────────┐                 │
│                         │  queue.jsonl    │                 │
│                         │  ./cache/       │                 │
│                         └────────┬────────┘                 │
│                                  │                           │
│  ┌───────────────────────────────┼─────────────────────┐   │
│  │ Docker Container              │ mount               │   │
│  │                               ▼                      │   │
│  │  ┌────────────────────────────────────────────┐     │   │
│  │  │  srgan-upscaler                            │     │   │
│  │  │  - Polls /app/cache/queue.jsonl           │     │   │
│  │  │  - Reads /media/movies/*.mkv              │     │   │
│  │  │  - FFmpeg + CUDA upscaling                │     │   │
│  │  │  - Writes HLS stream                      │     │   │
│  │  └────────────────────────────────────────────┘     │   │
│  │                                                      │   │
│  │  Volumes:                                            │   │
│  │  - /media:/media:ro          (read input)           │   │
│  │  - ./cache:/app/cache        (queue file)           │   │
│  │  - /mnt/media/upscaled:/data/upscaled (output)      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌────────────┐                                             │
│  │  HLS       │  HTTP                                       │
│  │  nginx     │◀────── Jellyfin plays http://...m3u8       │
│  │  :8080     │                                             │
│  └────────────┘                                             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Process Flow

### 1️⃣ User Plays Video
```
Jellyfin UI → Playback Start → Webhook Plugin
```

### 2️⃣ Webhook Sent
```http
POST http://localhost:5432/upscale-trigger
{"Path": "/media/movies/Example.mkv"}
```

### 3️⃣ Watchdog Processes
```python
# scripts/watchdog.py
1. Validate path exists
2. Create job: {"input": "...", "output": "...", "hls_dir": "..."}
3. Append to queue.jsonl
4. Start container: docker compose up -d
5. Return HLS URL
```

### 4️⃣ Container Polls Queue
```python
# scripts/srgan_pipeline.py (inside container)
while True:
    job = dequeue_job("/app/cache/queue.jsonl")
    if job:
        process_video(job)
    else:
        sleep(0.2)
```

### 5️⃣ Video Processing
```bash
ffmpeg \
  -hwaccel cuda \
  -i /media/movies/Example.mkv \
  -vf scale=iw*2:ih*2 \
  -c:v hevc_nvenc \
  -f hls /data/upscaled/hls/Example/stream.m3u8
```

### 6️⃣ Jellyfin Plays Stream
```
Jellyfin → http://localhost:8080/hls/Example/stream.m3u8
nginx serves HLS segments
User sees upscaled video
```

---

## Key Files

| File | Location | Purpose |
|------|----------|---------|
| **watchdog.py** | Host | Receives webhooks |
| **srgan_pipeline.py** | Container | Processes videos |
| **queue.jsonl** | Host (shared) | Job queue |
| **docker-compose.yml** | Host | Container config |
| **Dockerfile** | Host | Container image |

---

## Key Ports

| Port | Service | Purpose |
|------|---------|---------|
| **5432** | Watchdog (Flask) | Webhook receiver |
| **8080** | HLS Server (nginx) | Stream delivery |
| **8096** | Jellyfin | Main UI |

---

## Quick Commands

```bash
# Check watchdog status
sudo systemctl status srgan-watchdog
tail -f /var/log/srgan-watchdog.log

# Check container status
docker ps | grep srgan-upscaler
docker logs srgan-upscaler -f

# Check queue
cat /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl

# Manual trigger (no Jellyfin)
curl -X POST http://localhost:5432/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Path": "/media/movies/file.mkv"}'

# Test container can access media
docker compose exec srgan-upscaler ls -la /media/movies/
```

---

## Troubleshooting

### Webhook not received?
```bash
# Check watchdog running
sudo systemctl status srgan-watchdog

# Check webhook config
grep "http://localhost:5432" /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml
```

### Queue not written?
```bash
# Check watchdog logs
tail -f /var/log/srgan-watchdog.log

# Check file exists on host
test -f /media/movies/Example.mkv && echo "OK"
```

### Container can't find file?
```bash
# Check volume mounts
docker inspect srgan-upscaler | grep -A 20 Mounts

# Test access
docker compose exec srgan-upscaler test -f /media/movies/Example.mkv
```

### No output?
```bash
# Check container logs
docker logs srgan-upscaler -f

# Check output directory
ls -lh /mnt/media/upscaled/hls/
```

---

## Success Indicators

✅ Watchdog logs: `Webhook received! Extracted file path: /media/movies/Example.mkv`  
✅ Queue file exists: `cat queue.jsonl` shows job  
✅ Container running: `docker ps` shows `srgan-upscaler`  
✅ Processing: `docker logs` shows FFmpeg output  
✅ Output: `ls /mnt/media/upscaled/hls/Example/` shows `.m3u8` and `.ts` files  

---

**Simple, queue-based architecture for reliable video upscaling!** 🚀
