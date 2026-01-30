# Getting Started with Real-Time HDR SRGAN Pipeline

Complete step-by-step installation guide.

## Prerequisites

### System Requirements

- **OS**: Ubuntu 22.04+ (or compatible Linux distribution)
- **Hardware**: NVIDIA GPU (RTX series or datacenter GPUs recommended)
- **Software**:
  - Docker Engine 20.10+
  - Docker Compose v2
  - Python 3.8+
  - .NET 9 SDK (for Jellyfin plugin development)
  - .NET 9 Runtime (for Jellyfin plugin)

### Required Services

- Jellyfin 10.8+ (for webhook integration)
- NVIDIA drivers (525.x or newer)
- NVIDIA Container Toolkit

## Quick Start (Recommended)

**For most users, this is all you need:**

```bash
# 1. Clone the repository
git clone <repository-url>
cd Real-Time-HDR-SRGAN-Pipeline

# 2. Run the automated installer
./scripts/install_all.sh

# The installer automatically:
#   ✓ Installs system dependencies (Docker, .NET, Python, etc.)
#   ✓ Verifies system prerequisites
#   ✓ Builds Docker container
#   ✓ Sets up AI model (prompts for download)
#   ✓ Installs watchdog systemd service (auto-starts on boot)
#   ✓ Builds Jellyfin plugin (if Jellyfin detected)
#   ✓ Configures webhook for automatic upscaling on playback
#   ✓ Starts all services

# 3. Restart Jellyfin to load plugins
sudo systemctl restart jellyfin

# 4. Test webhook (optional)
python3 scripts/test_webhook.py

# Done! Service runs automatically in background.
```

## Manual Installation

If you prefer step-by-step control:

### Step 1: Verify Prerequisites

**Note**: The automated installer (`install_all.sh`) runs verification automatically.
You only need to run this manually if not using the installer.

```bash
# Run the verification script
python3 scripts/verify_setup.py

# This checks:
#   - Docker and Docker Compose v2
#   - Python 3 and required packages
#   - NVIDIA GPU and drivers
#   - NVIDIA Container Toolkit
#   - Directory structure
```

### Step 2: Install System Dependencies

**Ubuntu/Debian:**

```bash
# Update package list
sudo apt update

# Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in for group changes

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Verify GPU access
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

**Install Python dependencies:**

```bash
pip3 install flask requests
```

### Step 3: Configure Paths

**Important**: Ensure paths match between Jellyfin and the watchdog host.

```bash
# Check your Jellyfin library paths:
# Dashboard → Libraries → (Select a library) → Paths

# Create output directory
sudo mkdir -p /mnt/media/upscaled
sudo chmod 755 /mnt/media/upscaled

# Set environment variable (optional)
export UPSCALED_DIR=/mnt/media/upscaled
```

### Step 4: Build Docker Container

```bash
# Build the upscaler container
docker compose build srgan-upscaler

# Verify build
docker images | grep srgan
```

### Step 5: Install Watchdog Service

```bash
# Install as systemd service (runs automatically)
sudo ./scripts/install_systemd_watchdog.sh

# Or start manually for testing
./scripts/start_watchdog.sh
```

### Step 6: Setup Model (Optional)

**Note**: The automated installer (`install_all.sh`) prompts for model download.
You only need to run this manually if you skipped it during installation.

**Only needed if using ML model instead of ffmpeg.**

```bash
# Interactive setup with download option
./scripts/setup_model.sh

# Or manual download
wget https://github.com/Koushik0901/Swift-SRGAN/releases/download/v0.1/swift_srgan_4x.pth.tar
mv swift_srgan_4x.pth.tar models/swift_srgan_4x.pth

# Enable model in docker-compose.yml:
# SRGAN_ENABLE=1
```

### Step 7: Install Jellyfin Plugin

**Option A: Automatic (if using install_all.sh)**

The script automatically builds and installs the plugin if Jellyfin is detected.

**Option B: Manual Installation**

```bash
# Install .NET 9 (if not already installed)
distribution=$(. /etc/os-release; echo "$ID/$VERSION_ID")
wget https://packages.microsoft.com/config/${distribution}/packages-microsoft-prod.deb \
  -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y dotnet-sdk-9.0 aspnetcore-runtime-9.0

# Build the plugin
dotnet build jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj \
  -c Release \
  /p:JellyfinLibDir=/usr/lib/jellyfin/bin

# Install to Jellyfin
sudo mkdir -p /var/lib/jellyfin/plugins/RealTimeHDRSRGAN
PLUGIN_OUT=$(ls -d jellyfin-plugin/Server/bin/Release/net* | head -1)
sudo cp "${PLUGIN_OUT}"/* /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/

# Restart Jellyfin
sudo systemctl restart jellyfin
```

### Step 8: Configure Jellyfin Webhook

**Option 1: Automatic Configuration (Recommended)**

```bash
# Configure webhook automatically
sudo python3 scripts/configure_webhook.py http://YOUR_SERVER_IP:5000

# Restart Jellyfin to load configuration
sudo systemctl restart jellyfin
```

The script will create the webhook configuration with:
- Webhook name: "SRGAN 4K Upscaler"
- Endpoint: `http://YOUR_SERVER_IP:5000/upscale-trigger`
- Trigger: Playback Start
- Item types: Movies and Episodes
- Template: Includes `{{Path}}` variable for video file path

**Option 2: Manual Configuration**

See **[WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md)** for detailed manual webhook configuration.

Quick summary:
1. Install Jellyfin Webhook plugin: Dashboard → Plugins → Catalog → Webhooks
2. Add webhook: Dashboard → Plugins → Webhooks → Add Webhook
3. Configure:
   - URL: `http://YOUR_SERVER_IP:5000/upscale-trigger`
   - Type: Playback Start
   - Template: See WEBHOOK_CONFIGURATION_CORRECT.md for JSON template

### Step 9: Test the Setup

```bash
# Check service status
./scripts/manage_watchdog.sh status

# Test webhook
python3 scripts/test_webhook.py --test-file /path/to/video.mkv

# Check logs
./scripts/manage_watchdog.sh logs

# Play a video in Jellyfin and watch the logs
```

## Verification Checklist

After installation, verify:

- [ ] Docker container built: `docker images | grep srgan`
- [ ] Watchdog service running: `./scripts/manage_watchdog.sh status`
- [ ] Webhook responding: `curl http://localhost:5000/health`
- [ ] Jellyfin plugin installed: Dashboard → Plugins → Installed
- [ ] Jellyfin webhook configured: Dashboard → Plugins → Webhooks (or via `scripts/configure_webhook.py`)
- [ ] GPU accessible: `docker compose run --rm srgan-upscaler nvidia-smi`
- [ ] Output directory exists and writable
- [ ] Test video upscales successfully

## Service Management

The watchdog runs as a systemd service:

```bash
# Use the management script
./scripts/manage_watchdog.sh status     # Check status
./scripts/manage_watchdog.sh logs       # View logs
./scripts/manage_watchdog.sh restart    # Restart
./scripts/manage_watchdog.sh stop       # Stop
./scripts/manage_watchdog.sh start      # Start

# Service starts automatically on boot
# See SYSTEMD_SERVICE.md for more details
```

## Environment Variables

### For Watchdog (host)

```bash
# Set before starting watchdog
export UPSCALED_DIR=/mnt/media/upscaled
export SRGAN_QUEUE_FILE=./cache/queue.jsonl
export WATCHDOG_URL=http://localhost:5000  # Used by webhook auto-configuration
```

**Note**: `WATCHDOG_URL` is used during installation by `scripts/configure_webhook.py` to set the webhook endpoint. If your watchdog service runs on a different host or port, set this variable before running `install_all.sh`.

### For Container (docker-compose.yml)

```yaml
environment:
  - SRGAN_ENABLE=0                    # Set to 1 to use ML model
  - SRGAN_MODEL_PATH=/app/models/swift_srgan_4x.pth
  - SRGAN_QUEUE_FILE=/app/cache/queue.jsonl
  - UPSCALED_DIR=/data/upscaled
  - SRGAN_FFMPEG_ENCODER=hevc_nvenc   # GPU encoding
  - SRGAN_FFMPEG_HWACCEL=1            # Hardware acceleration
```

## Common Installation Issues

### Docker Compose v2 Error

**Symptom**: `KeyError: 'ContainerConfig'`

**Solution**: Use Docker Compose v2, not legacy docker-compose:
```bash
docker compose version  # Should show "Docker Compose version v2.x"
```

### GPU Not Detected

**Solution**:
```bash
# Verify drivers
nvidia-smi

# Test Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# Install NVIDIA Container Toolkit if needed
```

### Flask Not Installed

**Solution**:
```bash
pip3 install flask requests
# Service installation script does this automatically
```

### Port 5000 Already in Use

**Solution**:
```bash
# Check what's using port 5000
lsof -i :5000

# Kill the process or change the port
```

### Service Won't Start

**Solution**:
```bash
# Check logs
./scripts/manage_watchdog.sh recent

# Common causes and fixes in TROUBLESHOOTING.md
```

## Next Steps

1. **Read [WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md)** - Configure Jellyfin webhook
2. **Read [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)** - Learn service management
3. **Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - If you encounter issues
4. **Play a video in Jellyfin** - Watch it upscale automatically!

## Alternative Installation Methods

### Using One-Shot Installer with Flags

```bash
# With all optional features
RUN_GPU_DETECTION=1 RUN_CLEANUP=1 ./scripts/install_all.sh

# Custom Jellyfin paths
JELLYFIN_LIB_DIR=/usr/share/jellyfin/bin \
JELLYFIN_PLUGIN_DIR=/var/lib/jellyfin/plugins/RealTimeHDRSRGAN \
./scripts/install_all.sh
```

### Development Setup

```bash
# For development, run watchdog in foreground
python3 scripts/watchdog.py

# Or use the startup script
./scripts/start_watchdog.sh

# View logs in terminal
# Press Ctrl+C to stop
```

## Uninstallation

```bash
# Stop and remove watchdog service
./scripts/manage_watchdog.sh uninstall

# Stop and remove containers
docker compose down

# Remove plugin from Jellyfin
sudo rm -rf /var/lib/jellyfin/plugins/RealTimeHDRSRGAN
sudo systemctl restart jellyfin

# Remove project directory
cd ..
rm -rf Real-Time-HDR-SRGAN-Pipeline
```

## Support

If you encounter issues:

1. Run diagnostics: `python3 scripts/verify_setup.py`
2. Check logs: `./scripts/manage_watchdog.sh logs`
3. Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
4. Check webhook configuration: [WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md)

## See Also

- **[README.md](README.md)** - Project overview and features
- **[WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md)** - Webhook configuration reference
- **[SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)** - Service management guide
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Problem solving guide
- **[scripts/README.md](scripts/README.md)** - Script reference
