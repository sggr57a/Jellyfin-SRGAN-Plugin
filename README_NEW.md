# Real-Time HDR SRGAN Pipeline

A high-performance video upscaling pipeline for Jellyfin with NVIDIA GPU support. Automatically upscales videos to 4K when you start playback.

## Features

- **Webhook-Triggered Upscaling** - Automatically upscales videos when you press play in Jellyfin
- **Runs as System Service** - Starts automatically on boot, restarts on failure
- **GPU-Accelerated** - Uses NVIDIA GPU hardware encoding (NVENC) and decoding
- **HDR Support** - Preserves HDR10 metadata and color information
- **Growing File Playback** - Uses MPEG-TS container for real-time streaming while processing
- **Persistent Queue** - Queues multiple jobs, processes sequentially
- **NFS-Friendly** - Works with network-mounted media libraries
- **Automatic or Manual** - Use AI upscaling model or fast FFmpeg scaling

## Quick Start

```bash
# Clone repository
git clone <repository-url>
cd Real-Time-HDR-SRGAN-Pipeline

# One-command installation
./scripts/install_all.sh

# Verify setup
python3 scripts/verify_setup.py

# Configure Jellyfin webhook (see WEBHOOK_SETUP.md)

# Done! Play a video in Jellyfin and watch it upscale.
```

**✅ The watchdog runs as a systemd service - it starts automatically on boot!**

## How It Works

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

1. User plays video in Jellyfin
2. Jellyfin Webhook plugin sends POST to watchdog (port 5000)
3. Watchdog validates file path and adds job to queue
4. Watchdog starts Docker container if not running
5. Container processes video using GPU-accelerated ffmpeg or AI model
6. Upscaled video saved to output directory
7. User can play the upscaled version

## Documentation

**Start here:**
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete installation guide

**Configuration:**
- **[WEBHOOK_SETUP.md](WEBHOOK_SETUP.md)** - Configure Jellyfin webhook (required)
- **[SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)** - Manage the watchdog service

**Reference:**
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Fix common issues
- **[scripts/README.md](scripts/README.md)** - Script documentation

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
├── WEBHOOK_SETUP.md             # Webhook configuration
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

**Management:**
- `./scripts/manage_watchdog.sh [command]` - Manage systemd service
  - `status` - Check if running
  - `logs` - View live logs
  - `restart` - Restart service
  - `start/stop` - Start/stop service
  - `test` - Test webhook

**Setup:**
- `./scripts/install_all.sh` - Automated installation
- `./scripts/verify_setup.py` - Check prerequisites
- `./scripts/setup_model.sh` - Download AI model

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

1. Install Jellyfin Webhook plugin
2. Add webhook with URL: `http://YOUR_SERVER_IP:5000/upscale-trigger`
3. Set notification type: **Playback Start**
4. Use this JSON template:

```json
{
  "Item": {
    "Path": "{{Item.Path}}",
    "Name": "{{Item.Name}}",
    "Type": "{{Item.Type}}"
  }
}
```

See **[WEBHOOK_SETUP.md](WEBHOOK_SETUP.md)** for detailed instructions.

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
2. Configure webhook: See [WEBHOOK_SETUP.md](WEBHOOK_SETUP.md)
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
- [WEBHOOK_SETUP.md](WEBHOOK_SETUP.md) - Configuration
- [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md) - Service management
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving

## Acknowledgments

- Swift-SRGAN model: https://github.com/Koushik0901/Swift-SRGAN
- NVIDIA NVENC/NVDEC for hardware acceleration
- Jellyfin Webhook plugin for integration
