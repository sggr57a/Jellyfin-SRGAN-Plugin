# install_all.sh Dependency Installation Verification

**Date:** February 1, 2026  
**Script:** `/Users/jmclaughlin/Jellyfin-SRGAN-Plugin/scripts/install_all.sh`

---

## Executive Summary

⚠️ **CRITICAL FINDING:** The `install_all.sh` script **DOES NOT install system-level dependencies**. It assumes they are already installed.

### What's Missing

The script does **NOT** install:
- ❌ Docker
- ❌ Docker Compose v2
- ❌ .NET SDK 9.0
- ❌ Python 3
- ❌ System libraries (ffmpeg, curl, etc.)
- ❌ NVIDIA drivers
- ❌ NVIDIA Container Toolkit

### What It DOES Install

The script **DOES** install/configure:
- ✅ Python packages (Flask, requests) - via `install_systemd_watchdog.sh`
- ✅ Jellyfin plugin (C# build)
- ✅ Patched webhook plugin (C# build)
- ✅ Progress overlay files (CSS/JS)
- ✅ AI model (optional, user prompted)
- ✅ Docker containers (builds images)
- ✅ systemd watchdog service

---

## Detailed Analysis

### Step-by-Step Verification

#### Step 1: System Prerequisites Check ⚠️

```bash
# What it does:
python3 scripts/verify_setup.py  # Runs verification (non-blocking)
```

**Status:** ⚠️ **Verifies but does NOT install**
- Checks Docker, Docker Compose, Python, Flask, GPU
- If checks fail, shows warning but continues
- Does NOT install missing components

**Issue:** Users must manually install prerequisites before running script.

---

#### Step 2: Build Jellyfin Plugin ✅

```bash
# What it does:
dotnet build jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj -c Release
sudo cp bin/Release/net*/* /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
```

**Status:** ✅ **Works if .NET SDK is installed**
- Builds C# Jellyfin plugin
- Copies DLL to Jellyfin plugins directory
- Requires .NET SDK 9.0 (not installed by script)

**Prerequisite:** .NET SDK 9.0 must be installed separately

---

#### Step 2.3: Build Patched Webhook Plugin ✅

```bash
# What it does:
dotnet build jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook.sln -c Release
sudo cp Jellyfin.Plugin.Webhook.dll /var/lib/jellyfin/plugins/Webhook/
```

**Status:** ✅ **Works if .NET SDK is installed**
- Builds patched webhook plugin with {{Path}} variable support
- Copies DLL to Jellyfin plugins directory
- Critical for webhook functionality

**Prerequisite:** .NET SDK 9.0 must be installed separately

---

#### Step 2.5: Install Progress Overlay ✅

```bash
# What it does:
sudo cp jellyfin-plugin/playback-progress-overlay.css /usr/share/jellyfin/web/
sudo cp jellyfin-plugin/playback-progress-overlay.js /usr/share/jellyfin/web/
sudo cp jellyfin-plugin/playback-progress-overlay-centered.css /usr/share/jellyfin/web/
```

**Status:** ✅ **Fully automated**
- Copies CSS and JavaScript files to Jellyfin web directory
- No prerequisites needed (other than Jellyfin being installed)
- User must restart Jellyfin and refresh browser

---

#### Step 3: Setup AI Model (Optional) ⚠️

```bash
# What it does:
# Prompts user: "Download AI model now? (y/N)"
# If yes: runs setup_model.sh
```

**Status:** ⚠️ **Optional, user-prompted**
- AI model is NOT required (FFmpeg scaling is default)
- Only needed if SRGAN_ENABLE=1 in docker-compose.yml
- User can download later with `./scripts/setup_model.sh`

---

#### Step 4: Build Docker Images ✅

```bash
# What it does:
docker compose build
```

**Status:** ✅ **Works if Docker is installed**
- Builds srgan-upscaler Docker image
- Requires Docker and Docker Compose v2 (not installed by script)

**Prerequisite:** Docker and Docker Compose v2 must be installed separately

---

#### Step 5: Start Docker Container ✅

```bash
# What it does:
docker compose up -d srgan-upscaler
```

**Status:** ✅ **Works if Docker is installed**
- Starts the srgan-upscaler container in background
- Container processes upscaling jobs

---

#### Step 6: GPU Detection (Optional) ✅

```bash
# What it does:
bash jellyfin-plugin/gpu-detection.sh
```

**Status:** ✅ **Optional, non-critical**
- Detects NVIDIA GPU
- Fails gracefully if no GPU

---

#### Step 8: Install Watchdog Service ✅

```bash
# What it does:
sudo bash scripts/install_systemd_watchdog.sh
```

**Status:** ✅ **Installs Python packages if needed**
- **THIS IS THE ONLY STEP THAT INSTALLS DEPENDENCIES**
- Installs Flask and requests via pip if missing
- Creates systemd service
- Starts watchdog service

**What it installs:**
```bash
# Inside install_systemd_watchdog.sh:
su - "${CURRENT_USER}" -c "python3 -m pip install --user flask requests"
```

---

## Missing Dependencies

### Critical System Dependencies NOT Installed

The script assumes these are already installed:

| Dependency | Required For | Install Command (Ubuntu/Debian) |
|------------|--------------|--------------------------------|
| **Docker** | Containerization | `curl -fsSL https://get.docker.com \| sudo bash` |
| **Docker Compose v2** | Container orchestration | `sudo apt install docker-compose-plugin` |
| **.NET SDK 9.0** | Building Jellyfin plugins | See .NET installation below |
| **Python 3.8+** | Watchdog service | `sudo apt install python3 python3-pip` |
| **ffmpeg** | Video processing | `sudo apt install ffmpeg` |
| **curl/wget** | Downloads | `sudo apt install curl wget` |
| **git** | Version control | `sudo apt install git` |
| **NVIDIA Drivers** | GPU acceleration | `sudo ubuntu-drivers autoinstall` |
| **NVIDIA Container Toolkit** | Docker GPU access | See NVIDIA docs |

### .NET SDK 9.0 Installation

**Ubuntu 22.04:**
```bash
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo apt install dotnet-sdk-9.0
```

**Fedora:**
```bash
sudo dnf install dotnet-sdk-9.0
```

### NVIDIA Container Toolkit Installation

**Ubuntu/Debian:**
```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update
sudo apt-get install nvidia-docker2
sudo systemctl restart docker
```

---

## Python Packages

### Required Python Packages

From `requirements.txt`:

```python
opencv-python>=4.8.0       # Image processing
Pillow>=10.0.0             # Image manipulation
tqdm>=4.65.0               # Progress bars
numpy>=1.26.4              # Numerical operations
scipy>=1.10.0              # Scientific computing
imageio>=2.31.0            # Image I/O
imageio-ffmpeg>=0.4.8      # FFmpeg wrapper
torch>=2.4.0+cu121         # PyTorch (AI model, optional)
torchvision>=0.19.0+cu121  # PyTorch vision (AI model, optional)
torch-tensorrt>=2.4.0      # TensorRT (AI model, optional)
torchaudio>=2.4.0+cu121    # PyTorch audio (AI model, optional)
Flask>=3.0.3               # Web server (watchdog)
requests>=2.32.3           # HTTP client
```

### What Gets Installed

**By install_systemd_watchdog.sh:**
- ✅ Flask (required for watchdog)
- ✅ requests (required for watchdog)

**NOT installed by scripts:**
- ❌ opencv-python, Pillow, tqdm, numpy, scipy, imageio
- ❌ torch, torchvision, torch-tensorrt, torchaudio (AI model dependencies)

**Note:** These packages are only needed inside the Docker container, which has its own requirements installed during Docker build. The host system only needs Flask and requests for the watchdog service.

---

## Complete Installation Workflow

### What You Need to Do

**Before running install_all.sh:**

1. **Install Docker**
   ```bash
   curl -fsSL https://get.docker.com | sudo bash
   sudo usermod -aG docker $USER
   ```

2. **Install Docker Compose v2**
   ```bash
   sudo apt install docker-compose-plugin  # Ubuntu/Debian
   ```

3. **Install .NET SDK 9.0**
   ```bash
   # Ubuntu 22.04
   wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
   sudo dpkg -i packages-microsoft-prod.deb
   sudo apt update
   sudo apt install dotnet-sdk-9.0
   ```

4. **Install Python 3**
   ```bash
   sudo apt install python3 python3-pip
   ```

5. **(Optional) Install NVIDIA Drivers**
   ```bash
   sudo ubuntu-drivers autoinstall
   sudo reboot
   ```

6. **(Optional) Install NVIDIA Container Toolkit**
   ```bash
   sudo apt install nvidia-docker2
   sudo systemctl restart docker
   ```

**Then run install_all.sh:**
```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin
./scripts/install_all.sh
```

---

## Comparison: What's Documented vs What's Implemented

### DEPENDENCIES.md Claims

The `DEPENDENCIES.md` file (from Real-Time-HDR-SRGAN-Pipeline) states:

> **The `install_all.sh` script installs EVERYTHING automatically:**
> - ✅ Docker + Docker Compose v2
> - ✅ .NET 9.0 SDK
> - ✅ Python 3 + all packages
> - ✅ System utilities (ffmpeg, curl, etc.)
> - ✅ NVIDIA GPU support (if available)

### Reality

The current `install_all.sh` script in Jellyfin-SRGAN-Plugin:

> ❌ Does **NOT** install Docker
> ❌ Does **NOT** install Docker Compose v2
> ❌ Does **NOT** install .NET SDK 9.0
> ❌ Does **NOT** install Python 3
> ❌ Does **NOT** install system utilities
> ❌ Does **NOT** install NVIDIA drivers or Container Toolkit
> 
> ✅ **Only** installs Flask and requests (via install_systemd_watchdog.sh)

---

## Impact Assessment

### Critical Issues

1. **Script Won't Work on Fresh System**
   - Users on a fresh Ubuntu installation will get errors
   - Docker, .NET SDK, and other prerequisites must be installed manually
   - No clear documentation of prerequisites

2. **Documentation Mismatch**
   - DEPENDENCIES.md says installer does everything
   - Actual install_all.sh does minimal installation
   - Users will be confused

3. **DEPENDENCIES.md is from Wrong Directory**
   - The DEPENDENCIES.md file is from Real-Time-HDR-SRGAN-Pipeline
   - That directory may have had a different install_all.sh script
   - Documentation doesn't match current workspace

### What Works

1. **Jellyfin Integration**
   - Plugin building works (if .NET is installed)
   - Webhook plugin building works (if .NET is installed)
   - Overlay installation works
   - All Jellyfin-specific components are handled

2. **Docker Integration**
   - Container building works (if Docker is installed)
   - Container starting works
   - Service integration works

3. **Python Packages**
   - Flask and requests are installed automatically
   - Only essential packages for watchdog

---

## Recommendations

### Option 1: Fix install_all.sh (Add Dependency Installation)

**Add system dependency installation to install_all.sh:**

```bash
# Add to beginning of install_all.sh

# Step 0: Install system dependencies
echo "=========================================================================="
echo "Step 0: Installing system dependencies..."
echo "=========================================================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo bash
    sudo usermod -aG docker $USER
fi

# Install Docker Compose v2
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose v2..."
    case "$OS" in
        ubuntu|debian)
            sudo apt install -y docker-compose-plugin
            ;;
        fedora)
            sudo dnf install -y docker-compose-plugin
            ;;
    esac
fi

# Install .NET SDK 9.0
if ! dotnet --version &> /dev/null; then
    echo "Installing .NET SDK 9.0..."
    case "$OS" in
        ubuntu|debian)
            wget https://packages.microsoft.com/config/$OS/$(lsb_release -rs)/packages-microsoft-prod.deb
            sudo dpkg -i packages-microsoft-prod.deb
            sudo apt update
            sudo apt install -y dotnet-sdk-9.0
            ;;
        fedora)
            sudo dnf install -y dotnet-sdk-9.0
            ;;
    esac
fi

# Install Python 3
if ! command -v python3 &> /dev/null; then
    echo "Installing Python 3..."
    case "$OS" in
        ubuntu|debian)
            sudo apt install -y python3 python3-pip
            ;;
        fedora)
            sudo dnf install -y python3 python3-pip
            ;;
    esac
fi

# Install NVIDIA Container Toolkit (if GPU detected)
if command -v nvidia-smi &> /dev/null; then
    if ! docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi &> /dev/null; then
        echo "Installing NVIDIA Container Toolkit..."
        case "$OS" in
            ubuntu|debian)
                distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
                curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
                curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
                    sudo tee /etc/apt/sources.list.d/nvidia-docker.list
                sudo apt-get update
                sudo apt-get install -y nvidia-docker2
                sudo systemctl restart docker
                ;;
        esac
    fi
fi

echo "✓ System dependencies installed"
echo ""
```

### Option 2: Create Pre-Installation Script

**Create `scripts/install_prerequisites.sh`:**

```bash
#!/usr/bin/env bash
# Install all system prerequisites before running install_all.sh

echo "Installing prerequisites for Jellyfin-SRGAN-Plugin..."

# [Add installation code from Option 1 here]

echo ""
echo "Prerequisites installed. Now run:"
echo "  ./scripts/install_all.sh"
```

**Then update documentation:**
```bash
# Step 1: Install prerequisites
./scripts/install_prerequisites.sh

# Step 2: Install everything else
./scripts/install_all.sh
```

### Option 3: Update Documentation (Minimum Fix)

**Create new PREREQUISITES.md:**

```markdown
# Prerequisites

Before running `install_all.sh`, you must install:

1. Docker
2. Docker Compose v2
3. .NET SDK 9.0
4. Python 3.8+
5. (Optional) NVIDIA Drivers + Container Toolkit

See installation commands for your OS below...
```

**Update README.md and GETTING_STARTED.md to reference PREREQUISITES.md**

---

## Recommended Solution

**I recommend Option 1 + Option 3:**

1. **Fix install_all.sh** to install system dependencies
2. **Update documentation** to clearly state what's installed
3. **Add PREREQUISITES.md** for users who want manual control

This provides:
- ✅ One-command installation (as advertised)
- ✅ Clear documentation
- ✅ Manual option for advanced users

---

## Summary

### Current State

❌ **install_all.sh does NOT install system dependencies**
- Only installs Flask, requests, and Jellyfin-specific components
- Requires Docker, .NET SDK, Python 3, etc. to be pre-installed
- Documentation incorrectly claims it "installs everything"

### What Actually Gets Installed

✅ **By install_all.sh:**
- Flask and requests (Python packages)
- Jellyfin plugin (built from source)
- Patched webhook plugin (built from source)
- Progress overlay files (CSS/JS)
- Docker containers (builds images)
- systemd watchdog service

❌ **NOT installed by install_all.sh:**
- Docker
- Docker Compose v2
- .NET SDK 9.0
- Python 3
- System utilities (ffmpeg, curl, etc.)
- NVIDIA drivers
- NVIDIA Container Toolkit

### Impact

Users will encounter errors if they:
- Don't have Docker installed
- Don't have .NET SDK installed
- Don't have Python 3 installed
- Try to use on a fresh system

### Recommended Fix

Add system dependency installation to install_all.sh (see Option 1 above)

---

**Verification Date:** February 1, 2026  
**Script Analyzed:** `/Users/jmclaughlin/Jellyfin-SRGAN-Plugin/scripts/install_all.sh`  
**Status:** ⚠️ **INCOMPLETE - Missing system dependency installation**
