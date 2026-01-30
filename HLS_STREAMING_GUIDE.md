## HLS Real-Time Streaming Guide

Complete guide for playing upscaled content while it's still being processed.

## Overview

**Traditional Mode:** User plays video → Entire file upscales → User manually switches to upscaled version later

**HLS Streaming Mode:** User plays video → Upscaling starts → After 10-15 seconds, stream switches to 4K → Continue watching upscaled content → Final file saved for future playback

## How It Works

### HLS (HTTP Live Streaming)

HLS breaks video into small segments (6 seconds each):

```
stream.m3u8          (playlist - updates as new segments arrive)
├── segment_000.ts   (0-6 seconds) ← Available immediately
├── segment_001.ts   (6-12 seconds) ← Created while you watch segment_000
├── segment_002.ts   (12-18 seconds) ← Created while you watch segment_001
└── ...
```

**User Experience:**
1. Click play on a video in Jellyfin
2. Original video starts playing
3. Webhook triggers upscaling in background
4. After 10-15 seconds, you get a notification
5. Video switches to 4K upscaled HLS stream
6. Continue watching while upscaling completes
7. Final 4K file saved for instant playback next time

## Quick Start

### 1. Enable HLS Streaming

Already enabled by default! Check `docker-compose.yml`:

```yaml
srgan-upscaler:
  environment:
    - ENABLE_HLS_STREAMING=1  # ← Must be 1
    - HLS_SERVER_HOST=localhost
    - HLS_SERVER_PORT=8080
```

### 2. Start Services

```bash
# Start all services (including HLS server)
docker compose up -d

# Start watchdog
python3 scripts/watchdog.py
# OR if using systemd:
sudo systemctl start srgan-watchdog
```

### 3. Test HLS Functionality

```bash
# Run comprehensive test suite
./scripts/test_hls_streaming.sh

# This will:
# - Check all prerequisites
# - Start services
# - Create test video
# - Trigger upscaling
# - Monitor HLS generation
# - Verify server access
```

### 4. Test with Real Playback

**Option A: VLC Player**
```bash
# After triggering upscale, play HLS stream directly
vlc http://localhost:8080/hls/YourMovie/stream.m3u8
```

**Option B: Jellyfin Web Interface**
```bash
# 1. Install hls.js in Jellyfin
# 2. Add hls-streaming.js to Jellyfin web root
# 3. Play video normally - automatic switching enabled
```

**Option C: Browser Developer Console**
```javascript
// Manual HLS control
window.JellyfinHLS.checkStatus('/data/movies/Movie.mkv')
window.JellyfinHLS.switchStream('http://localhost:8080/hls/Movie/stream.m3u8')
```

## Monitoring

### Real-Time Progress Monitoring

```bash
# Monitor HLS segment generation
python3 scripts/monitor_hls.py /data/upscaled/hls/Movie

# With video duration for progress percentage
python3 scripts/monitor_hls.py /data/upscaled/hls/Movie \
  --input-file /data/movies/Movie.mkv

# Output:
# Segments:   45 | Duration:  270.0s | Progress:  37.5% | Rate: 1.12x | ETA:  00:04:30 | 🔄 STREAMING
```

### Performance Monitoring

```bash
# Check if upscaling is fast enough for real-time
python3 scripts/audit_performance.py --output /data/upscaled/Movie.ts

# Must show >= 1.0x multiplier for smooth streaming
# Output:
# Frames:    450 | Sample FPS:  25.34 | Avg FPS:  24.12 | Multiplier:  1.01x | ✅ STABLE
```

## Cleanup

### Automatic Cleanup (Recommended)

Add to crontab for daily cleanup:

```bash
# Clean up old HLS segments daily at 3 AM
crontab -e

# Add:
0 3 * * * /usr/bin/python3 /path/to/scripts/cleanup_hls.py --max-age 24
```

### Manual Cleanup

```bash
# Dry run (see what would be deleted)
python3 scripts/cleanup_hls.py --dry-run

# Remove completed streams (where final file exists)
python3 scripts/cleanup_hls.py --completed-only

# Remove streams older than 48 hours
python3 scripts/cleanup_hls.py --max-age 48

# Full cleanup (completed + old)
python3 scripts/cleanup_hls.py
```

## Configuration

### Environment Variables

**Watchdog (`watchdog.py`):**
```bash
ENABLE_HLS_STREAMING=1        # Enable/disable HLS mode
HLS_SERVER_HOST=localhost     # HLS server hostname
HLS_SERVER_PORT=8080          # HLS server port
UPSCALED_DIR=/data/upscaled   # Output directory
```

**Pipeline (`srgan_pipeline.py`):**
```bash
HLS_SEGMENT_TIME=6            # Segment duration (seconds)
HLS_LIST_SIZE=0               # Max segments in playlist (0=unlimited)
HLS_FLAGS=append_list+omit_endlist  # FFmpeg HLS flags
SRGAN_SCALE_FACTOR=2.0        # Upscale multiplier
```

**Docker Compose:**
```yaml
services:
  hls-server:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - /mnt/media/upscaled/hls:/usr/share/nginx/html/hls:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
```

### nginx Configuration

The `nginx.conf` file configures the HLS server:

```nginx
server {
    listen 80;
    
    location /hls {
        alias /usr/share/nginx/html/hls;
        
        # CORS headers for cross-origin playback
        add_header 'Access-Control-Allow-Origin' '*' always;
        
        # Cache control
        add_header 'Cache-Control' 'no-cache' always;
        
        # HLS MIME types
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }
}
```

## Jellyfin Integration

### Method 1: Client-Side JavaScript (Easiest)

1. **Copy `hls-streaming.js` to Jellyfin:**
   ```bash
   cp jellyfin-plugin/hls-streaming.js /path/to/jellyfin/web/hls-streaming.js
   ```

2. **Inject into Jellyfin web interface:**
   ```html
   <!-- Add to Jellyfin's index.html or create custom theme -->
   <script src="/hls-streaming.js"></script>
   ```

3. **Configure:**
   ```javascript
   // Edit hls-streaming.js CONFIG section
   const CONFIG = {
       watchdogUrl: 'http://YOUR_SERVER:5000',
       hlsServerUrl: 'http://YOUR_SERVER:8080',
       autoSwitch: false  // true = auto-switch, false = ask user
   };
   ```

### Method 2: Plugin API (Advanced)

1. **Build the enhanced plugin:**
   ```bash
   cd jellyfin-plugin/Server
   dotnet build
   ```

2. **Copy to Jellyfin:**
   ```bash
   cp -r bin/Release/net8.0/* /path/to/jellyfin/plugins/RealTimeHDRSRGAN/
   ```

3. **Restart Jellyfin:**
   ```bash
   sudo systemctl restart jellyfin
   ```

4. **Use plugin API from Jellyfin:**
   ```csharp
   // Check HLS status
   POST /Plugins/RealTimeHDRSRGAN/CheckHlsStatus
   { "FilePath": "/data/movies/Movie.mkv" }
   
   // Trigger upscale
   POST /Plugins/RealTimeHDRSRGAN/TriggerUpscale
   { "FilePath": "/data/movies/Movie.mkv" }
   
   // Get HLS URL
   GET /Plugins/RealTimeHDRSRGAN/GetHlsUrl?filePath=/data/movies/Movie.mkv
   ```

### Method 3: Manual Switching

For testing or when automatic switching isn't available:

```bash
# 1. Start playing video in Jellyfin
# 2. After 15 seconds, open browser console (F12)
# 3. Get HLS URL
curl http://localhost:5000/hls-status/Movie.mkv

# 4. In browser console, switch manually:
const video = document.querySelector('video');
const hls = new Hls();
hls.loadSource('http://localhost:8080/hls/Movie/stream.m3u8');
hls.attachMedia(video);
```

## Performance Requirements

### Minimum Requirements

**For Real-Time Streaming (1.0x):**
- GPU: NVIDIA GTX 1060 or better
- VRAM: 6GB minimum
- Encoder: NVENC support (hevc_nvenc)
- CPU: 4 cores minimum
- Storage: Fast SSD for HLS segments

**Network (Local):**
- Bandwidth: 25+ Mbps for 4K HEVC
- Latency: < 50ms (local network)

### Check Your Performance

```bash
# Run benchmark test
./scripts/test_hls_streaming.sh

# Monitor during actual playback
python3 scripts/audit_performance.py

# Required results:
# - Real-time multiplier: >= 1.0x (minimum)
# - Recommended: >= 1.2x (for buffer)
# - Ideal: >= 1.5x (smooth experience)
```

### Optimize Performance

**If too slow (< 1.0x):**

1. **Reduce resolution:**
   ```yaml
   environment:
     - SRGAN_SCALE_FACTOR=1.5  # Instead of 2.0
   ```

2. **Faster encoder preset:**
   ```yaml
   environment:
     - SRGAN_FFMPEG_PRESET=p1  # Fastest (lower quality)
     # p1=fastest, p4=balanced, p7=slowest
   ```

3. **Lower quality:**
   ```yaml
   environment:
     - SRGAN_FFMPEG_CRF=23  # Higher = lower quality/smaller
     # 18=high, 23=medium, 28=low
   ```

4. **Disable HDR tone mapping:**
   ```yaml
   environment:
     - SRGAN_ENABLE=0  # Use simple upscaling only
   ```

## Troubleshooting

### Problem: No HLS segments generated

**Check:**
```bash
# 1. Verify streaming enabled
curl http://localhost:5000/health | grep streaming_enabled

# 2. Check Docker logs
docker compose logs -f srgan-upscaler

# 3. Verify HLS directory exists
ls -la /data/upscaled/hls/

# 4. Check permissions
ls -ld /data/upscaled/hls/
# Should be writable by Docker user
```

**Fix:**
```bash
# Enable streaming
# Edit docker-compose.yml:
ENABLE_HLS_STREAMING=1

# Restart services
docker compose up -d --force-recreate

# Create HLS directory
sudo mkdir -p /data/upscaled/hls
sudo chown -R $USER:$USER /data/upscaled/hls
```

### Problem: HLS stream not accessible

**Check:**
```bash
# 1. Test HLS server
curl -I http://localhost:8080/health

# 2. Test playlist access
curl -I http://localhost:8080/hls/Movie/stream.m3u8

# 3. Check nginx logs
docker compose logs hls-server

# 4. Verify volume mounts
docker compose config | grep -A 5 hls-server
```

**Fix:**
```bash
# Check nginx config
cat nginx.conf

# Verify volume path matches
# nginx.conf: /usr/share/nginx/html/hls
# docker-compose.yml: /mnt/media/upscaled/hls:/usr/share/nginx/html/hls:ro

# Restart HLS server
docker compose restart hls-server
```

### Problem: Playback stutters/buffers

**Cause:** Upscaling slower than real-time

**Check:**
```bash
python3 scripts/audit_performance.py
# Look for: Multiplier < 1.0x
```

**Fix:**
```bash
# Option 1: Reduce quality (fastest)
# Edit docker-compose.yml:
- SRGAN_FFMPEG_PRESET=p1
- SRGAN_FFMPEG_CRF=23

# Option 2: Lower resolution
- SRGAN_SCALE_FACTOR=1.5

# Option 3: Disable AI upscaling
- SRGAN_ENABLE=0

# Restart
docker compose up -d --force-recreate
```

### Problem: High disk usage

**Cause:** HLS segments not cleaned up

**Check:**
```bash
# Check HLS directory size
du -sh /data/upscaled/hls/

# List old streams
python3 scripts/cleanup_hls.py --dry-run
```

**Fix:**
```bash
# Manual cleanup
python3 scripts/cleanup_hls.py

# Setup automatic cleanup (cron)
crontab -e
# Add: 0 3 * * * /usr/bin/python3 /path/to/scripts/cleanup_hls.py --max-age 24

# Or reduce segment retention
# Edit docker-compose.yml:
- HLS_LIST_SIZE=10  # Only keep last 10 segments
```

### Problem: Jellyfin won't switch to HLS

**Check:**
```bash
# 1. Verify hls.js loaded
# Open browser console (F12):
console.log(typeof Hls)  # Should not be 'undefined'

# 2. Check script injection
view-source:http://jellyfin/web/
# Look for: <script src="/hls-streaming.js"></script>

# 3. Check for errors
# Browser console should show:
# [HLS] Initializing HLS streaming integration
```

**Fix:**
```bash
# Method 1: Manual injection
# Add to Jellyfin's custom CSS/JS:
# Dashboard → General → Custom CSS/JS

# Method 2: Use plugin API
# Rebuild plugin with HLS support
cd jellyfin-plugin/Server
dotnet build
cp -r bin/Release/net8.0/* /jellyfin/plugins/RealTimeHDRSRGAN/
sudo systemctl restart jellyfin
```

## Advanced Configuration

### Custom Segment Duration

```yaml
# Shorter segments = Lower latency, More overhead
HLS_SEGMENT_TIME=4  # 4 seconds

# Longer segments = Higher latency, Less overhead
HLS_SEGMENT_TIME=10  # 10 seconds

# Recommended: 6 seconds (balance)
```

### Multiple Quality Levels (Adaptive)

```python
# TODO: Not yet implemented
# Future feature: Generate multiple quality streams
# - 1080p stream (backup)
# - 4K stream (primary)
# Client switches based on bandwidth
```

### Pre-Upscale Popular Content

```bash
# Pre-upscale before playback
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "Item": {
      "Path": "/data/movies/PopularMovie.mkv",
      "Name": "PopularMovie"
    }
  }'

# No delay when user plays!
```

## API Reference

### Watchdog Endpoints

**Health Check:**
```bash
GET /health
Response: {
  "status": "healthy",
  "streaming_enabled": true
}
```

**Trigger Upscale:**
```bash
POST /upscale-trigger
Body: {
  "Item": {
    "Path": "/data/movies/Movie.mkv",
    "Name": "Movie"
  }
}
Response: {
  "status": "started",
  "hls_url": "http://localhost:8080/hls/Movie/stream.m3u8",
  "estimated_delay_seconds": 15
}
```

**Check HLS Status:**
```bash
GET /hls-status/<filename>
Response: {
  "status": "streaming",
  "hls_url": "http://localhost:8080/hls/Movie/stream.m3u8",
  "segments": 45,
  "complete": false
}
```

### HLS Server Endpoints

**Playlist:**
```
GET /hls/<movie_name>/stream.m3u8
Content-Type: application/vnd.apple.mpegurl
```

**Segments:**
```
GET /hls/<movie_name>/segment_000.ts
Content-Type: video/mp2t
```

**Health:**
```
GET /health
Response: "healthy"
```

## Performance Benchmarks

### Example Results

**Test System:**
- GPU: NVIDIA RTX 3060 (12GB)
- CPU: AMD Ryzen 5 5600X
- Storage: NVMe SSD
- Input: 1080p @ 24 FPS
- Output: 4K @ 24 FPS (HEVC)

**Results:**
- Processing speed: 1.3x real-time
- Initial delay: ~12 seconds
- Segment generation: 4-5 seconds per segment
- Memory usage: ~8GB GPU, ~4GB RAM
- Storage: ~500MB HLS buffer
- Final file: ~15GB (2-hour movie)

**User Experience:**
- Smooth playback after initial delay
- No stuttering or buffering
- Quality matches offline upscaling
- Final file ready after playback ends

## Comparison: Batch vs Streaming

| Aspect | Batch Mode | HLS Streaming |
|--------|------------|---------------|
| **Time to watch** | Wait for full upscale | 10-15 seconds |
| **Disk usage** | Final file only | +500MB temp |
| **Performance** | Any speed works | Must be >= 1.0x |
| **Complexity** | Simple | More complex |
| **Best for** | Pre-upscaling | Live playback |

## Next Steps

1. **Test your setup:**
   ```bash
   ./scripts/test_hls_streaming.sh
   ```

2. **Check performance:**
   ```bash
   python3 scripts/audit_performance.py
   ```

3. **Set up cleanup:**
   ```bash
   crontab -e
   # Add: 0 3 * * * /usr/bin/python3 /path/to/scripts/cleanup_hls.py
   ```

4. **Configure Jellyfin:**
   - Add hls-streaming.js to web interface
   - Test with a sample video
   - Adjust auto-switch settings

5. **Monitor usage:**
   ```bash
   # Watch logs
   docker compose logs -f

   # Monitor disk usage
   watch du -sh /data/upscaled/hls/

   # Check active streams
   ls -la /data/upscaled/hls/
   ```

## Support

**Issues:**
- Check logs: `docker compose logs -f`
- Run tests: `./scripts/test_hls_streaming.sh`
- Monitor performance: `python3 scripts/audit_performance.py`

**Documentation:**
- Full architecture: `REAL_TIME_STREAMING.md`
- Setup guide: This file
- Troubleshooting: Above section
- Scripts README: `scripts/README.md`

**Performance Tips:**
- Use local network (not internet)
- Fast SSD for HLS segments
- GPU with NVENC support
- Dedicated GPU (not shared)
- Monitor with `audit_performance.py`

## Summary

HLS streaming enables **watching upscaled content in real-time**:
- ✅ 10-15 second delay (vs hours of waiting)
- ✅ Seamless quality switch
- ✅ Final file saved for future
- ✅ Same quality as batch upscaling
- ⚠️ Requires fast GPU (>= 1.0x real-time)
- ⚠️ Extra disk space during streaming

**Ready to start? Run:**
```bash
./scripts/test_hls_streaming.sh
```
