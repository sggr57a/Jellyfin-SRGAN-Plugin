# Scripts Directory

Operational scripts used by the Jellyfin webhook flow and maintenance tasks.

## Quick Reference

### Setup & Verification Tools (Run These First)

```bash
# 1. Verify your system has all prerequisites
python3 verify_setup.py

# 2. Test webhook connectivity and configuration
python3 test_webhook.py

# 3. Start watchdog with automatic checks
./start_watchdog.sh -d
```

### Runtime Scripts

```bash
# Start webhook listener (receives playback events from Jellyfin)
python3 watchdog.py

# Or use the convenience script
./start_watchdog.sh        # foreground
./start_watchdog.sh -d     # background
```

## Script Overview

### Setup & Testing

**`verify_setup.py`** - System prerequisites verification ⭐ AUTO-RUN
- Checks Docker, Docker Compose v2, Python, Flask
- Verifies NVIDIA GPU and drivers
- Tests Docker GPU access
- Validates configuration files
- Checks directory structure
- **Note**: Automatically run by `install_all.sh`

**`setup_model.sh`** - Model file setup and download ⭐ AUTO-PROMPT
- Downloads Swift-SRGAN model automatically
- Renames .pth.tar to .pth
- Handles existing files
- Provides manual download instructions
- **Note**: Automatically prompted by `install_all.sh`

**`manage_watchdog.sh`** - Systemd service management
- Start/stop/restart the watchdog service
- View logs and status
- Enable/disable auto-start on boot
- Install/uninstall systemd service
- Test webhook health

**`test_webhook.py`** - Webhook testing tool
- Tests health check endpoint
- Validates webhook connectivity
- Tests with real video files
- Provides detailed diagnostic output

**`start_watchdog.sh`** - Convenient watchdog startup
- Checks and installs prerequisites
- Creates required directories
- Validates port availability
- Supports foreground/background operation
- Provides health check after startup
- **Note**: For manual testing; production uses systemd service

### Runtime

**`watchdog.py`** - Webhook listener (enhanced with logging)
- Receives POST requests from Jellyfin Webhook plugin
- Validates file paths and existence
- Adds jobs to processing queue
- Starts the srgan-upscaler container
- Provides detailed logging for debugging
- Endpoints:
  - `/upscale-trigger` - Main webhook endpoint
  - `/health` - Health check
  - `/` - API documentation

**`srgan_pipeline.py`** - Video processing pipeline
- Runs inside Docker container
- Reads jobs from queue file
- Processes videos with ffmpeg or ML model
- Outputs upscaled video files

### Pipeline & Model

**`your_model_file.py`** - ML model implementation
- Optional SRGAN model interface
- Called when `SRGAN_ENABLE=1`

### Maintenance

**`audit_performance.py`** - Performance monitoring ⭐ FIXED
- Monitors upscaling FPS in real-time
- Calculates real-time multiplier (actual FPS / target FPS)
- Shows performance status (STABLE/SLOW/VERY SLOW)
- Provides final statistics summary
- Test with: `./test_audit_performance.sh`
- Requires: ffmpeg/ffprobe

**`cleanup_upscaled.py`** - Cleanup utility
- Remove old upscaled files

**`test_audit_performance.sh`** - Test suite for audit_performance.py ⭐ NEW
- Tests syntax and functionality
- Validates error handling
- Creates test video for monitoring demo

**`test_pipeline.py`** - Pipeline testing
- Test the video processing pipeline directly

**`monitor_hls.py`** - HLS progress monitoring ⭐ NEW
- Monitor real-time HLS upscaling progress
- Shows segment count, duration, progress, speed, ETA
- Auto-detects video duration with ffprobe

**`cleanup_hls.py`** - HLS cleanup utility ⭐ NEW
- Clean up HLS segments after final file is ready
- Remove abandoned/old HLS streams
- Supports dry-run mode

**`test_hls_streaming.sh`** - HLS streaming test suite ⭐ NEW
- Comprehensive tests for HLS functionality
- Validates segment generation
- Tests playlist integrity
- Verifies server access

**`test_progress_overlay.sh`** - Progress overlay test suite ⭐ NEW
- Tests progress overlay JavaScript/CSS
- Validates API endpoints
- Checks file syntax

**`test_loading_behavior.sh`** - Loading indicator test suite ⭐ NEW
- Validates loading stays until playback
- Tests event detection
- Verifies state management

**`verify_overlay_install.sh`** - Overlay installation verification ⭐ NEW
- Checks if overlay files are installed at `/usr/share/jellyfin/web/`
- Verifies file permissions
- Tests Jellyfin service status
- Provides troubleshooting guidance

### Installation

**`install_all.sh`** - One-shot installer ⭐ ENHANCED
- Verifies system prerequisites
- Prompts for model download (optional)
- Builds Docker container
- Installs systemd service (auto-starts on boot)
- Builds Jellyfin plugin (if detected)
- **Installs progress overlay to `/usr/share/jellyfin/web/`** ⭐ NEW
- Configures everything automatically

**`install_systemd_watchdog.sh`** - Systemd service setup
- Creates watchdog systemd service
- Enables auto-start on boot

**`install_srgan.py`** - Legacy systemd helper
- Older installation script

## Usage Examples

### First-Time Setup

**Recommended: Use the automated installer**

```bash
# One command does everything
./install_all.sh

# This automatically:
# - Runs verify_setup.py
# - Prompts for model download (setup_model.sh)
# - Builds Docker container
# - Installs systemd service
# - Builds Jellyfin plugin
# - Installs progress overlay to Jellyfin web directory
# - Starts everything

# After installation, verify overlay:
./verify_overlay_install.sh
```

**Manual Setup** (if you prefer control):

```bash
# 1. Verify everything is ready
python3 verify_setup.py

# 2. Install Flask if needed
pip3 install flask requests

# 3. Setup model file (optional, only needed if using ML model)
./setup_model.sh

# 4. Build the container
cd .. && docker compose build srgan-upscaler

# 5. Install systemd service
sudo ./install_systemd_watchdog.sh

# Or start watchdog manually for testing
./start_watchdog.sh
```

### Setting Up the Model (Optional)

```bash
# Automatic download and setup
./setup_model.sh

# The script will:
# 1. Check for existing model files
# 2. Offer to download if missing
# 3. Automatically rename .pth.tar to .pth
# 4. Show configuration instructions
```

### Monitoring Performance

While an upscaling job is running, monitor performance:

```bash
# Monitor default output location
python3 audit_performance.py

# Monitor specific file
python3 audit_performance.py --output /data/upscaled/movie.ts --target-fps 24

# Faster updates (2 second intervals)
python3 audit_performance.py --sample-seconds 2

# The script shows:
# - Current frame count
# - Sample FPS (this interval)
# - Average FPS (overall)
# - Real-time multiplier (FPS / target FPS)
# - Performance status (STABLE/SLOW/VERY SLOW)
```

**Example output:**
```
Frames:    450 | Sample FPS:  25.34 | Avg FPS:  24.12 | Multiplier:  1.01x | ✅ STABLE
```

**Test the script:**
```bash
./test_audit_performance.sh
```

### Testing the Webhook

```bash
# Test health check
curl http://localhost:5000/health

# Run automated tests
python3 test_webhook.py

# Test with a real video file
python3 test_webhook.py --test-file /mnt/media/movies/sample.mkv

# Manual test
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item": {"Path": "/mnt/media/movies/test.mkv"}}'
```

### Testing the Progress Overlay

```bash
# Verify overlay files are installed
./verify_overlay_install.sh

# Test progress API endpoint
curl http://localhost:5000/progress/test_video.mkv

# Test progress overlay JavaScript/CSS
./test_progress_overlay.sh

# Test loading behavior
./test_loading_behavior.sh
```

### Testing HLS Streaming

```bash
# Comprehensive HLS test
./test_hls_streaming.sh

# Monitor HLS progress manually
python3 monitor_hls.py test_video.mkv

# Clean up HLS segments
python3 cleanup_hls.py --dry-run  # Preview
python3 cleanup_hls.py            # Actually clean
```

### Running in Production (Systemd Service)

```bash
# Install service (done automatically by install_all.sh)
sudo ./install_systemd_watchdog.sh

# Check service status
./manage_watchdog.sh status

# View live logs
./manage_watchdog.sh logs

# Restart service
./manage_watchdog.sh restart

# Check webhook health
./manage_watchdog.sh health
```

### Running in Foreground (Testing)

```bash
# Start in foreground to see logs
./start_watchdog.sh

# Or start in background
./start_watchdog.sh -d

# Monitor logs
tail -f ../watchdog.log

# Check status
curl http://localhost:5000/health

# Stop (find PID from log output)
kill <PID>
```

### Managing the Systemd Service

```bash
# Use the management script
./manage_watchdog.sh [command]

# Examples:
./manage_watchdog.sh status      # Show detailed status
./manage_watchdog.sh logs        # Follow live logs
./manage_watchdog.sh recent      # Show last 50 log entries
./manage_watchdog.sh restart     # Restart the service
./manage_watchdog.sh stop        # Stop the service
./manage_watchdog.sh start       # Start the service
./manage_watchdog.sh test        # Test webhook functionality
./manage_watchdog.sh health      # Quick health check
./manage_watchdog.sh enable      # Enable auto-start on boot
./manage_watchdog.sh disable     # Disable auto-start on boot
./manage_watchdog.sh uninstall   # Remove systemd service
```

### Direct Systemd Commands

```bash
# Status
sudo systemctl status srgan-watchdog.service

# Start/Stop/Restart
sudo systemctl start srgan-watchdog.service
sudo systemctl stop srgan-watchdog.service
sudo systemctl restart srgan-watchdog.service

# Enable/Disable auto-start
sudo systemctl enable srgan-watchdog.service
sudo systemctl disable srgan-watchdog.service

# View logs
sudo journalctl -u srgan-watchdog.service -f          # Live
sudo journalctl -u srgan-watchdog.service -n 100      # Last 100 lines
sudo journalctl -u srgan-watchdog.service --since today  # Today's logs
```

### Debugging

```bash
# Run with verbose logging (edit watchdog.py line 10: level=logging.DEBUG)

# Monitor everything in real-time
# Terminal 1: Watchdog
python3 watchdog.py

# Terminal 2: Container logs
cd .. && docker compose logs -f srgan-upscaler

# Terminal 3: Queue file
watch -n 1 cat ../cache/queue.jsonl

# Terminal 4: GPU usage
watch -n 1 nvidia-smi
```

## Environment Variables

### For watchdog.py (host)

```bash
# Output directory for upscaled videos
export UPSCALED_DIR=/mnt/media/upscaled

# Queue file location
export SRGAN_QUEUE_FILE=/home/user/srgan/cache/queue.jsonl
```

### For srgan_pipeline.py (container)

Set in `docker-compose.yml`:
```yaml
environment:
  - SRGAN_QUEUE_FILE=/app/cache/queue.jsonl
  - SRGAN_QUEUE_POLL_SECONDS=0.2
  - SRGAN_ENABLE=0  # Set to 1 to use ML model
  - SRGAN_FFMPEG_ENCODER=hevc_nvenc
  - UPSCALED_DIR=/data/upscaled
```

## Files Created During Operation

```
Real-Time-HDR-SRGAN-Pipeline/
├── cache/
│   ├── queue.jsonl          # Job queue (one JSON per line)
│   └── queue.jsonl.lock     # Lock file for queue access
├── watchdog.log             # Log file (when running in background)
└── /mnt/media/upscaled/     # Output directory (configurable)
    └── *.ts                 # Upscaled video files
```

## Troubleshooting

### Watchdog won't start

```bash
# Check if port 5000 is in use
lsof -i :5000

# Check Flask is installed
python3 -c "import flask; print('OK')"

# Install dependencies
pip3 install flask requests
```

### Webhook not receiving requests

```bash
# Test locally
curl http://localhost:5000/health

# Check firewall (Ubuntu)
sudo ufw status
sudo ufw allow 5000

# Check Jellyfin webhook logs
# Dashboard → Plugins → Webhooks → View Logs
```

### Container not starting

```bash
# Check container status
cd .. && docker compose ps

# View logs
docker compose logs srgan-upscaler

# Rebuild if needed
docker compose build srgan-upscaler
```

## See Also

- [WEBHOOK_SETUP.md](../WEBHOOK_SETUP.md) - Detailed webhook configuration guide
- [README.md](../README.md) - Main project documentation
- [INSTALLATION.md](../INSTALLATION.md) - Installation instructions
