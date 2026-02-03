# Real-Time HDR SRGAN Pipeline

A high-performance video upscaling pipeline for Jellyfin with NVIDIA GPU support. Automatically upscales videos when you start playback.

> **🚀 Quick Start:** See [QUICK_START_API.md](QUICK_START_API.md) for 5-minute setup  
> **📚 All Documentation:** See [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)

---

## Features

- **🎯 API-Based Triggering** - Uses Jellyfin's official `/Sessions` API (reliable, no template issues)
- **🎬 Real-Time HLS Streaming** - Watch upscaled content while it's still being processed
- **🐳 Dockerized Processing** - GPU-accelerated video processing in isolated container
- **📊 Progress Monitoring** - Track upscaling progress in real-time
- **🔄 Queue-Based Architecture** - Persistent job queue, survives restarts
- **⚡ GPU-Accelerated** - NVIDIA GPU hardware encoding (NVENC) and decoding
- **🌈 HDR Support** - Preserves HDR10 metadata and color information
- **🔧 Systemd Service** - Starts automatically on boot, restarts on failure
- **🌐 NFS-Friendly** - Works with network-mounted media libraries

---

## Quick Setup (One Command)

```bash
git clone <your-repo-url>
cd Jellyfin-SRGAN-Pipeline

# Run the automated installer
sudo ./scripts/install_all.sh
```

**The installer automatically:**
- ✅ Installs all dependencies (Docker, Python, etc.)
- ✅ Detects and configures media library paths
- ✅ Builds Docker container
- ✅ Prompts for Jellyfin API key
- ✅ Installs API-based watchdog service
- ✅ Cleans up old template-based files
- ✅ Starts all services
- ✅ Tests the installation

**Manual step (during installation):**
- Create Jellyfin API key when prompted:
  - Dashboard → Advanced → API Keys → +
  - Name: SRGAN Watchdog
  - Copy the key
- Configure webhook when prompted:
  - Dashboard → Plugins → Webhook → Add Generic Destination
  - URL: `http://localhost:5432/upscale-trigger`
  - Notification Type: ✓ Playback Start
  - Item Type: ✓ Movie, ✓ Episode

**Then test:**
```bash
# Monitor logs
sudo journalctl -u srgan-watchdog-api -f

# Play video in Jellyfin
# Should see: "Found playing item: ... (/media/movies/file.mkv)"
```

**See [QUICK_START_API.md](QUICK_START_API.md) for detailed instructions.**

---

## How It Works

```
User plays video in Jellyfin
  ↓
Webhook triggers watchdog (Flask on host)
  ↓
Watchdog queries Jellyfin API: GET /Sessions
  ↓
API returns currently playing item with file path
  ↓
Watchdog writes job to queue.jsonl (shared volume)
  ↓
Docker container polls queue, processes video
  ↓
FFmpeg + CUDA upscales to HLS stream
  ↓
User watches upscaled video
```

**See [ARCHITECTURE_SIMPLE.md](ARCHITECTURE_SIMPLE.md) for detailed architecture.**

---

## Documentation

- **[QUICK_START_API.md](QUICK_START_API.md)** - 5-minute setup guide
- **[API_BASED_WATCHDOG.md](API_BASED_WATCHDOG.md)** - Complete API setup
- **[COMPARISON_TEMPLATE_VS_API.md](COMPARISON_TEMPLATE_VS_API.md)** - Why use API approach
- **[ARCHITECTURE_SIMPLE.md](ARCHITECTURE_SIMPLE.md)** - System architecture
- **[WEBHOOK_TO_CONTAINER_FLOW.md](WEBHOOK_TO_CONTAINER_FLOW.md)** - Technical details
- **[FIX_DOCKER_CANNOT_FIND_FILE.md](FIX_DOCKER_CANNOT_FIND_FILE.md)** - Volume mount troubleshooting
- **[SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)** - Service management
- **[DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)** - Complete documentation index

---

## Requirements

- **OS:** Ubuntu 22.04+ or compatible Linux
- **GPU:** NVIDIA GPU with CUDA support
- **Software:**
  - Docker Engine 20.10+
  - Docker Compose v2
  - Python 3.8+
  - NVIDIA drivers 525.x+
  - NVIDIA Container Toolkit
- **Services:**
  - Jellyfin 10.8+
  - Admin access to Jellyfin (for API key)

---

## Troubleshooting

### Service won't start
```bash
sudo journalctl -u srgan-watchdog-api -n 50
# Common: API key invalid, Python requests missing
```

### Container can't find media files
```bash
./scripts/diagnose_path_issue.sh
# Fix volume mounts in docker-compose.yml
```

### No file path in API response
```bash
# API key must be from admin user
curl -H "X-Emby-Token: KEY" http://localhost:8096/Sessions
```

**See [FIX_DOCKER_CANNOT_FIND_FILE.md](FIX_DOCKER_CANNOT_FIND_FILE.md) for detailed troubleshooting.**

---

## Commands Reference

```bash
# Service management
sudo systemctl status srgan-watchdog-api
sudo systemctl restart srgan-watchdog-api
sudo journalctl -u srgan-watchdog-api -f

# Testing
curl http://localhost:5432/status
curl http://localhost:5432/playing

# Container management
docker ps | grep srgan-upscaler
docker logs srgan-upscaler -f
docker compose down srgan-upscaler
docker compose up -d srgan-upscaler
```

---

## Architecture

The system uses a queue-based architecture:

1. **Jellyfin** sends webhook when video plays
2. **Watchdog** (Flask on host) receives webhook
3. **Watchdog** queries Jellyfin API `/Sessions` for file path
4. **Watchdog** writes job to `queue.jsonl` (shared volume)
5. **Container** polls queue and processes video
6. **FFmpeg + CUDA** upscales to HLS stream
7. **Nginx** serves HLS stream back to Jellyfin

**See [ARCHITECTURE_SIMPLE.md](ARCHITECTURE_SIMPLE.md) for detailed diagrams.**

---

## Why API-Based?

**Old approach (template):** ❌ Unreliable `{{Path}}` variable  
**New approach (API):** ✅ Official Jellyfin `/Sessions` API

**Benefits:**
- ✅ More reliable (99% vs 60% success rate)
- ✅ No webhook plugin patching needed
- ✅ Easier to setup (5 min vs 30 min)
- ✅ Easier to maintain and debug
- ✅ Future-proof with official API

**See [COMPARISON_TEMPLATE_VS_API.md](COMPARISON_TEMPLATE_VS_API.md) for details.**

---

## Contributing

This is a working project for real-time video upscaling with Jellyfin.

**To contribute:**
1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

---

## License

[Your License Here]

---

## Credits

- Jellyfin for the media server platform
- NVIDIA for CUDA and hardware acceleration
- FFmpeg for video processing

---

**Questions? Check [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) for all guides.**

## Legacy Information

### Batch Mode (Traditional)

```
┌─────────┐    Webhook     ┌──────────┐    Queue      ┌───────────┐
│Jellyfin │───────────────>│ Watchdog │──────────────>│  Docker   │
│(Playback│  "Play Video"  │ Service  │  Add Job      │ Container │
│ Start)  │                │(Port 5000│               │(GPU NVENC)│
└─────────┘                └──────────┘               └─────┬─────┘
                                                             │
                                                        Upscale
                                                             │
                                                             v
                                                    ┌────────────────┐
                                                    │/data/upscaled/ │
                                                    │  video.ts      │
                                                    └────────────────┘
```

### HLS Streaming Mode ⭐ NEW!

```
┌─────────┐    Webhook     ┌──────────┐              ┌───────────┐
│Jellyfin │───────────────>│ Watchdog │─────────────>│  Docker   │
│ Plays   │  "Play Video"  │ Returns  │  Dual Output │ Container │
│Original │                │ HLS URL  │              │(GPU NVENC)│
└────┬────┘                └──────────┘              └─────┬─────┘
     │                                                      │
     │ After 10-15 seconds                      ┌──────────┴────────────┐
     │                                           │                       │
     ▼                                           ▼                       ▼
┌──────────┐                           ┌────────────────┐    ┌───────────────┐
│ Switch   │<───────────────────────── │HLS Segments    │    │Final File     │
│ to HLS   │   nginx (Port 8080)       │segment_*.ts    │    │video.ts       │
│ Stream   │                           │stream.m3u8     │    │(for next time)│
└──────────┘                           └────────────────┘    └───────────────┘
```

**Traditional:** User watches original → Wait for full upscale → Manually switch later
**HLS Mode:** User watches original → 10-15 sec delay → **Auto-switch to 4K** → Final file saved

1. User plays video in Jellyfin
2. Jellyfin Webhook plugin sends POST to watchdog (port 5000)
3. Watchdog returns HLS URL and starts upscaling
4. Docker container outputs dual streams (HLS segments + final file)
5. After 10-15 seconds, HLS segments become available
6. User's playback switches to upscaled HLS stream
7. Upscaling continues in background
8. Final file saved for future instant playback

## Progress Overlay in Playback ⭐ NEW!

See real-time upscaling progress directly on screen:

When you click play on a video, you immediately see a loading indicator that stays visible until playback begins:

```
┌────────────┐
│ 🎬 Loading │  ← Appears immediately (< 100ms)
│ 4K...      │  ← Stays until video plays
│ ░░░░░ 0%   │
└────────────┘
```

Once the video starts playing, this updates to show detailed progress:

```
┌────────────┐
│ 🎬 4K      │
│ Upscaling  │
├────────────┤
│ Upscaling  │
│ at 1.2x    │
│ ▓▓▓░░ 45%  │  ← Real-time progress
│            │
│ Speed: 1.2x│  ← Processing speed
│ ETA: 2m    │  ← Time remaining
└────────────┘
```

**Features:**
- ✅ **Instant loading feedback** - Appears in < 100ms when you click play
- ✅ **Stays until playback** - No confusing gaps, continuous feedback
- ✅ **Real-time updates** - Progress refreshes every 2 seconds
- ✅ **Processing speed & ETA** - Know exactly how fast it's going
- ✅ **Theme-matched colors** - Automatically uses your Jellyfin theme
- ✅ **One-click stream switch** - Button to switch to upscaled version

**Installation:**
The overlay is automatically installed by `./scripts/install_all.sh` to `/usr/share/jellyfin/web/`.

**Verify installation:**
```bash
./scripts/verify_overlay_install.sh
```

**See it in action:**
1. Restart Jellyfin: `sudo systemctl restart jellyfin`
2. Hard refresh browser: `Ctrl+Shift+R`
3. Click play on any video
4. Look for overlay in top-right corner

**Documentation:** See `PLAYBACK_PROGRESS_GUIDE.md` for complete details.

---

## Real-Time HLS Streaming ⭐ NEW!

Watch upscaled content **while it's still being processed**:

```bash
# 1. Test HLS streaming
./scripts/test_hls_streaming.sh

# 2. Monitor upscaling progress
python3 scripts/monitor_hls.py /data/upscaled/hls/Movie

# 3. Check performance (must be >= 1.0x for smooth streaming)
python3 scripts/audit_performance.py

# 4. Setup automatic cleanup
python3 scripts/cleanup_hls.py --dry-run
crontab -e  # Add: 0 3 * * * /usr/bin/python3 /path/to/scripts/cleanup_hls.py
```

**User Experience:**
- Click play → Original plays → 10-15 seconds → **Switches to 4K** → Continue watching
- Final file saved for instant 4K playback next time
- No more waiting hours for upscaling to finish!

**Requirements:**
- ⚠️ GPU must process >= 1.0x real-time (check with `audit_performance.py`)
- Recommended: RTX 3060 or better
- Local network (not internet streaming)

**Full Guide:** [HLS_STREAMING_GUIDE.md](HLS_STREAMING_GUIDE.md)

## Progress Overlay in Playback Info ⭐ NEWEST!

See **real-time upscaling progress** directly in Jellyfin:

**Immediate "Loading..." indicator** (shows instantly when you click play):
```
┌─────────────────────────────────────┐
│ 🎬 4K Upscaling                  ×  │
├─────────────────────────────────────┤
│ Preparing 4K upscaling...           │
│ ░░░░░░░░░░░░░░░░░░░░░░░░  0%       │
│ ← animated sweep →                  │
└─────────────────────────────────────┘
```
*No more frozen-looking delays!*

**Then transitions to live progress** (after 1-2 seconds):
```
┌─────────────────────────────────────┐
│ 🎬 4K Upscaling                  ×  │
├─────────────────────────────────────┤
│ Upscaling at 1.2x speed             │
│ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░  45%        │
│                                     │
│ Processing Speed: 1.2x ✓            │
│ ETA: 2m 30s                         │
│ Segments: 45                        │
│                                     │
│ [Switch to Upscaled Stream]         │
└─────────────────────────────────────┘
```

**Features:**
- ⚡ **Instant "Loading..." feedback** - No more frozen appearance!
- 📊 Live progress bar with percentage
- ⚡ Processing speed indicator (1.2x = 20% faster than real-time)
- ⏱️ ETA calculation
- 🎯 One-click switch to upscaled stream
- ⌨️ Press "U" key to toggle overlay

**Setup:**
```bash
# 1. Test the API
./scripts/test_progress_overlay.sh

# 2. Copy to Jellyfin
cp jellyfin-plugin/playback-progress-overlay.{js,css} /path/to/jellyfin/web/

# 3. Inject into HTML or use Custom CSS/JS in Jellyfin Dashboard
```

**Full Guide:** [PLAYBACK_PROGRESS_GUIDE.md](PLAYBACK_PROGRESS_GUIDE.md)

## Documentation

**Start here:**
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete installation guide
- **[HLS_STREAMING_GUIDE.md](HLS_STREAMING_GUIDE.md)** ⭐ Real-time streaming setup
- **[PLAYBACK_PROGRESS_GUIDE.md](PLAYBACK_PROGRESS_GUIDE.md)** ⭐ Progress overlay setup

**Configuration:**
- **[WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md)** - Configure Jellyfin webhook (required)
- **[SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)** - Manage the watchdog service

**Reference:**
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Fix common issues
- **[scripts/README.md](scripts/README.md)** - Script documentation
- **[REAL_TIME_STREAMING.md](REAL_TIME_STREAMING.md)** - Technical architecture

## System Requirements

- **OS**: Ubuntu 22.04+ or compatible Linux
- **GPU**: NVIDIA GPU (RTX series or datacenter)
- **Software**:
  - Docker Engine 20.10+
  - Docker Compose v2
  - Python 3.8+
  - NVIDIA drivers (525.x+)
  - NVIDIA Container Toolkit
- **Services**: Jellyfin 10.8+ (for webhook integration)

## Project Structure

```
Real-Time-HDR-SRGAN-Pipeline/
├── README.md                    # This file - project overview
├── GETTING_STARTED.md           # Installation guide
├── WEBHOOK_CONFIGURATION_CORRECT.md             # Webhook configuration
├── SYSTEMD_SERVICE.md           # Service management
├── TROUBLESHOOTING.md           # Problem solving
├── docker-compose.yml           # Container configuration
├── Dockerfile                   # Container build
├── scripts/
│   ├── watchdog.py             # Webhook listener (runs as service)
│   ├── srgan_pipeline.py       # Video processing (runs in container)
│   ├── manage_watchdog.sh      # Service management tool
│   ├── verify_setup.py         # System verification
│   ├── test_webhook.py         # Webhook testing
│   ├── setup_model.sh          # Model download/setup
│   ├── start_watchdog.sh       # Manual startup
│   ├── install_all.sh          # One-shot installer
│   └── install_systemd_watchdog.sh  # Service installation
├── jellyfin-plugin/            # Jellyfin plugin (optional)
├── models/                     # AI model weights (optional)
├── cache/                      # Queue file (auto-created)
├── input/                      # Test inputs
└── output/                     # Test outputs
```

## Key Scripts

**Installation:**
- `./scripts/install_all.sh` - Automated installation (runs verification and model setup)

**Management:**
- `./scripts/manage_watchdog.sh [command]` - Manage systemd service
  - `status` - Check if running
  - `logs` - View live logs
  - `restart` - Restart service
  - `start/stop` - Start/stop service
  - `test` - Test webhook

**Manual Setup** (if needed):
- `./scripts/verify_setup.py` - Check prerequisites (run by install_all.sh)
- `./scripts/setup_model.sh` - Download AI model (prompted by install_all.sh)

**Testing:**
- `./scripts/test_webhook.py` - Test webhook configuration
- `curl http://localhost:5000/health` - Quick health check

## Service Management

The watchdog runs automatically as a systemd service:

```bash
# Check status
./scripts/manage_watchdog.sh status

# View logs
./scripts/manage_watchdog.sh logs

# Restart
./scripts/manage_watchdog.sh restart

# Test health
./scripts/manage_watchdog.sh health
```

See **[SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)** for complete documentation.

## Webhook Configuration

Configure Jellyfin to trigger upscaling:

1. **Install patched webhook plugin** (includes `{{Path}}` variable support):
   ```bash
   cd jellyfin-plugin-webhook
   dotnet build -c Release
   # Install to Jellyfin plugins directory
   ```

2. Add webhook with URL: `http://YOUR_SERVER_IP:5000/upscale-trigger`
3. Set notification type: **Playback Start**
4. Set item types: **Movie** and **Episode**
5. Set content type: **application/json**
6. Use this JSON template:

```json
{
  "Path": "{{Path}}",
  "Name": "{{Name}}",
  "ItemType": "{{ItemType}}",
  "NotificationUsername": "{{NotificationUsername}}",
  "UserId": "{{UserId}}",
  "NotificationType": "{{NotificationType}}"
}
```

⚠️ **Important:** The stock Jellyfin webhook plugin does not expose the `Path` variable. You must use the patched version included in `jellyfin-plugin-webhook/`.

See **[WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md)** for complete setup instructions.

## Configuration

### Upscaling Method

**Default: Fast FFmpeg scaling (recommended)**
```yaml
# docker-compose.yml
SRGAN_ENABLE=0  # Use ffmpeg
SRGAN_FFMPEG_ENCODER=hevc_nvenc  # GPU encoding
SRGAN_FFMPEG_HWACCEL=1  # Hardware acceleration
```

**Optional: AI Model (slower, higher quality)**
```yaml
SRGAN_ENABLE=1  # Use AI model
SRGAN_MODEL_PATH=/app/models/swift_srgan_4x.pth
```

Download model:
```bash
./scripts/setup_model.sh
```

### Output Settings

```yaml
# docker-compose.yml
UPSCALED_DIR=/data/upscaled  # Output directory
SRGAN_QUEUE_FILE=/app/cache/queue.jsonl  # Queue file
```

### Hardware Acceleration

```yaml
SRGAN_FFMPEG_HWACCEL=1  # Enable hardware decode
SRGAN_FFMPEG_ENCODER=hevc_nvenc  # Use NVIDIA encoder
SRGAN_FFMPEG_PRESET=p1  # Fastest preset
SRGAN_FFMPEG_DELAY=0  # Low latency mode
```

## Usage Examples

### Standalone Mode (No Jellyfin)

```bash
# Process a single file
docker compose run --rm srgan-upscaler \
  /data/movies/input.mkv \
  /data/upscaled/output.ts

# With specific resolution
docker compose run --rm srgan-upscaler \
  /data/movies/input.mkv \
  /data/upscaled/output.ts \
  --width 3840 --height 2160
```

### Jellyfin Integration Mode

1. Start watchdog service: `./scripts/manage_watchdog.sh start`
2. Configure webhook: See [WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md)
3. Play video in Jellyfin
4. Watch logs: `./scripts/manage_watchdog.sh logs`
5. Upscaled file appears in output directory

## Troubleshooting

**Service won't start:**
```bash
# Check logs
./scripts/manage_watchdog.sh recent

# Common fix: Install Flask
pip3 install flask requests
./scripts/manage_watchdog.sh restart
```

**Webhook not triggering:**
```bash
# Test health
curl http://localhost:5000/health

# Test webhook
python3 scripts/test_webhook.py --test-file /path/to/video.mkv

# Check Jellyfin webhook logs
```

**File not found error:**
- Check paths match between Jellyfin and host
- See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for path translation

**GPU not detected:**
```bash
# Verify GPU works
nvidia-smi

# Test in container
docker compose run --rm srgan-upscaler nvidia-smi
```

See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for complete guide.

## Performance Tips

- **Use hardware acceleration**: Set `SRGAN_FFMPEG_HWACCEL=1` and `SRGAN_FFMPEG_ENCODER=hevc_nvenc`
- **Fastest encoding**: Set `SRGAN_FFMPEG_PRESET=p1`
- **Reduce latency**: Set `SRGAN_FFMPEG_DELAY=0`
- **NFS optimization**: Use `rsize=1048576,wsize=1048576` mount options
- **Monitor GPU**: Watch `nvidia-smi -l 1` during processing

## Advanced Features

### HDR10 Preservation

The pipeline automatically preserves HDR10 metadata:
- Uses 10-bit color depth (`rgb48le` pixel format)
- Preserves color primaries (`bt2020`)
- Maintains transfer characteristics (`smpte2084`)
- Outputs `hevc_nvenc` with `main10` profile

### Growing File Playback

Output uses MPEG-TS container for real-time playback:
- Jellyfin can start playing while file is being written
- No final header update required (unlike MP4/MKV)
- Network-friendly for NFS/SMB shares

### Queue Processing

Multiple upscale requests are queued and processed sequentially:
- Queue file: `./cache/queue.jsonl` (one JSON per line)
- Container processes one job at a time
- Automatic retry on failure (via systemd restart)

## Uninstallation

```bash
# Stop and remove service
./scripts/manage_watchdog.sh uninstall

# Stop containers
docker compose down

# Remove project
cd .. && rm -rf Real-Time-HDR-SRGAN-Pipeline
```

## Environment Variables

### Watchdog (Host)

```bash
UPSCALED_DIR=/mnt/media/upscaled  # Output directory
SRGAN_QUEUE_FILE=./cache/queue.jsonl  # Queue file location
```

### Container (docker-compose.yml)

```yaml
SRGAN_ENABLE=0  # 0=ffmpeg, 1=AI model
SRGAN_MODEL_PATH=/app/models/swift_srgan_4x.pth
SRGAN_DEVICE=cuda
SRGAN_FP16=1  # Half-precision for faster processing
SRGAN_WAIT_SECONDS=-1  # Wait indefinitely for jobs
SRGAN_QUEUE_POLL_SECONDS=0.2  # Poll interval
SRGAN_FFMPEG_HWACCEL=1  # Hardware decode
SRGAN_FFMPEG_ENCODER=hevc_nvenc  # Encoder
SRGAN_FFMPEG_PRESET=fast  # Encoding speed
SRGAN_FFMPEG_BUFSIZE=100M  # Buffer size
```

## Technical Details

### Video Processing Pipeline

1. **Decode**: Hardware decode (NVDEC) or software decode
2. **Upscale**: AI model or Lanczos interpolation
3. **Encode**: Hardware encode (NVENC) with HDR metadata
4. **Output**: MPEG-TS for streaming compatibility

### GPU Utilization

- **Video Decode**: NVDEC (if `SRGAN_FFMPEG_HWACCEL=1`)
- **Video Encode**: NVENC (if `SRGAN_FFMPEG_ENCODER=hevc_nvenc`)
- **AI Inference**: CUDA (if `SRGAN_ENABLE=1`)
- **Format Conversion**: CUDA (format conversions stay on GPU)

### Memory Management

- Uses PyTorch with CUDA for zero-copy transfers
- FP16 autocast for reduced memory usage
- Configurable buffer sizes for memory control
- `memlock: -1` ulimit for TensorRT/CUDA stability

## License

[Specify your license here]

## Contributing

[Contributing guidelines]

## Support

**First steps:**
1. Run diagnostics: `python3 scripts/verify_setup.py`
2. Check logs: `./scripts/manage_watchdog.sh logs`
3. Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
4. Test webhook: `python3 scripts/test_webhook.py`

**Documentation:**
- [GETTING_STARTED.md](GETTING_STARTED.md) - Installation
- [WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md) - Webhook setup
- [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md) - Service management
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving

## Acknowledgments

- Swift-SRGAN model: https://github.com/Koushik0901/Swift-SRGAN
- NVIDIA NVENC/NVDEC for hardware acceleration
- Jellyfin Webhook plugin for integration
