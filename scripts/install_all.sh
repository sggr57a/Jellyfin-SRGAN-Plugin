#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=========================================================================="
echo "Real-Time HDR SRGAN Pipeline - Complete Installation"
echo "=========================================================================="
echo ""
echo "This script will install ALL required dependencies including:"
echo "  - Docker & Docker Compose v2"
echo "  - .NET SDK 9.0"
echo "  - Python 3 & pip"
echo "  - System utilities (ffmpeg, curl, wget, git, jq)"
echo "  - NVIDIA Container Toolkit (if GPU detected)"
echo "  - Jellyfin plugins & overlays"
echo ""
echo "⚠️  This script requires sudo privileges for system package installation."
echo ""
read -p "Continue with installation? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Installation cancelled."
  exit 0
fi
echo ""

# Detect OS
echo "=========================================================================="
echo "Detecting operating system..."
echo "=========================================================================="
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS=$ID
  VER=$VERSION_ID
  echo "Detected: $PRETTY_NAME"
else
  echo -e "${RED}✗ Cannot detect OS. Unsupported system.${NC}" >&2
  exit 1
fi
echo ""

# Check if running as root (for sudo commands)
if [[ $EUID -eq 0 ]]; then
  SUDO=""
  CURRENT_USER="${SUDO_USER:-root}"
else
  SUDO="sudo"
  CURRENT_USER="${USER}"
fi

# Step 0: Install system dependencies
echo "=========================================================================="
echo -e "${BLUE}Step 0: Installing system dependencies...${NC}"
echo "=========================================================================="
echo ""

# Update package lists
echo "Updating package lists..."
case "$OS" in
  ubuntu|debian|linuxmint|pop)
    $SUDO apt-get update
    ;;
  fedora|rhel|centos|rocky|almalinux)
    $SUDO dnf check-update || true
    ;;
  arch|manjaro)
    $SUDO pacman -Sy
    ;;
  *)
    echo -e "${YELLOW}⚠ Unknown OS: $OS. Package installation may fail.${NC}"
    ;;
esac
echo -e "${GREEN}✓ Package lists updated${NC}"
echo ""

# Install Docker
echo "Installing Docker..."
if command -v docker >/dev/null 2>&1; then
  DOCKER_VERSION=$(docker --version)
  echo -e "${GREEN}✓ Docker already installed: $DOCKER_VERSION${NC}"
else
  case "$OS" in
    ubuntu|debian|linuxmint|pop)
      # Install prerequisites
      $SUDO apt-get install -y ca-certificates curl gnupg lsb-release

      # Add Docker's official GPG key
      $SUDO install -m 0755 -d /etc/apt/keyrings
      if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
        curl -fsSL https://download.docker.com/linux/${OS}/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
      fi

      # Set up repository
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

      # Install Docker
      $SUDO apt-get update
      $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin #docker-compose-v2
      ;;

    fedora)
      $SUDO dnf -y install dnf-plugins-core
      $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin #docker-compose-plugin
      ;;

    rhel|centos|rocky|almalinux)
      $SUDO dnf -y install dnf-plugins-core
      $SUDO dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin #docker-compose-plugin
      ;;

    arch|manjaro)
      $SUDO pacman -S --noconfirm docker docker-compose
      ;;

    *)
      echo -e "${RED}✗ Automatic Docker installation not supported for $OS${NC}"
      echo "Please install Docker manually: https://docs.docker.com/engine/install/"
      exit 1
      ;;
  esac

  # Start and enable Docker
  $SUDO systemctl start docker
  $SUDO systemctl enable docker

  # Add current user to docker group
  if [[ "$CURRENT_USER" != "root" ]]; then
    $SUDO usermod -aG docker "$CURRENT_USER"
    echo -e "${YELLOW}⚠ Added $CURRENT_USER to docker group${NC}"
    echo "  You may need to log out and back in for this to take effect."
    echo "  Or run: newgrp docker"
  fi

  echo -e "${GREEN}✓ Docker installed successfully${NC}"
fi
echo ""

# Verify Docker Compose v2
echo "Verifying Docker Compose v2..."
if docker compose version >/dev/null 2>&1; then
  COMPOSE_VERSION=$(docker compose version --short)
  echo -e "${GREEN}✓ Docker Compose v2 installed: $COMPOSE_VERSION${NC}"
else
  echo -e "${RED}✗ Docker Compose v2 not found after installation${NC}"
  echo "This should not happen. Docker installation may have failed."
  exit 1
fi
echo ""

# Install .NET SDK 9.0
echo "Installing .NET SDK 9.0..."
if dotnet --list-sdks 2>/dev/null | grep -q "9.0"; then
  DOTNET_VERSION=$(dotnet --version)
  echo -e "${GREEN}✓ .NET SDK 9.0 already installed: $DOTNET_VERSION${NC}"
else
  case "$OS" in
    ubuntu|debian|linuxmint|pop)
      # Download Microsoft package repository
      PACKAGES_MICROSOFT_PROD_DEB="packages-microsoft-prod.deb"
      if [[ "$OS" == "ubuntu" || "$OS" == "linuxmint" || "$OS" == "pop" ]]; then
        # For Ubuntu-based distros
        UBUNTU_VERSION="${VER}"
        # Map Linux Mint/Pop OS versions to Ubuntu versions
        if [[ "$OS" == "linuxmint" ]]; then
          case "${VER%%.*}" in
            21) UBUNTU_VERSION="22.04" ;;
            20) UBUNTU_VERSION="20.04" ;;
            *) UBUNTU_VERSION="22.04" ;;
          esac
        elif [[ "$OS" == "pop" ]]; then
          case "${VER%%.*}" in
            22) UBUNTU_VERSION="22.04" ;;
            20) UBUNTU_VERSION="20.04" ;;
            *) UBUNTU_VERSION="22.04" ;;
          esac
        fi
        wget -q https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb -O /tmp/${PACKAGES_MICROSOFT_PROD_DEB}
      else
        # For Debian
        wget -q https://packages.microsoft.com/config/debian/${VER}/packages-microsoft-prod.deb -O /tmp/${PACKAGES_MICROSOFT_PROD_DEB}
      fi

      $SUDO dpkg -i /tmp/${PACKAGES_MICROSOFT_PROD_DEB}
      rm /tmp/${PACKAGES_MICROSOFT_PROD_DEB}

      # Install .NET SDK
      $SUDO apt-get update
      $SUDO apt-get install -y dotnet-sdk-9.0
      ;;

    fedora|rhel|centos|rocky|almalinux)
      # Add Microsoft repository
      $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
      if [[ "$OS" == "fedora" ]]; then
        wget -q https://packages.microsoft.com/config/fedora/${VER}/prod.repo -O /tmp/microsoft-prod.repo
      else
        # RHEL/CentOS/Rocky/AlmaLinux
        $SUDO dnf install -y https://packages.microsoft.com/config/rhel/${VER%%.*}/packages-microsoft-prod.rpm
      fi

      if [[ -f /tmp/microsoft-prod.repo ]]; then
        $SUDO mv /tmp/microsoft-prod.repo /etc/yum.repos.d/microsoft-prod.repo
        $SUDO chown root:root /etc/yum.repos.d/microsoft-prod.repo
      fi

      # Install .NET SDK
      $SUDO dnf install -y dotnet-sdk-9.0
      ;;

    arch|manjaro)
      # .NET is in AUR, install manually or use dotnet-install script
      echo -e "${YELLOW}⚠ .NET SDK installation on Arch requires manual steps${NC}"
      echo "Install from AUR: yay -S dotnet-sdk"
      echo "Or use: https://dot.net/v1/dotnet-install.sh"
      ;;

    *)
      echo -e "${YELLOW}⚠ Automatic .NET installation not supported for $OS${NC}"
      echo "Please install manually: https://dotnet.microsoft.com/download/dotnet/9.0"
      ;;
  esac

  echo -e "${GREEN}✓ .NET SDK 9.0 installed${NC}"
fi
echo ""

# Install Python 3
echo "Installing Python 3 and pip..."
if command -v python3 >/dev/null 2>&1; then
  PYTHON_VERSION=$(python3 --version)
  echo -e "${GREEN}✓ Python 3 already installed: $PYTHON_VERSION${NC}"
else
  case "$OS" in
    ubuntu|debian|linuxmint|pop)
      $SUDO apt-get install -y python3 python3-pip python3-venv
      ;;
    fedora|rhel|centos|rocky|almalinux)
      $SUDO dnf install -y python3 python3-pip
      ;;
    arch|manjaro)
      $SUDO pacman -S --noconfirm python python-pip
      ;;
  esac
  echo -e "${GREEN}✓ Python 3 installed${NC}"
fi
echo ""

# Install system utilities
echo "Installing system utilities (ffmpeg, curl, wget, git, jq, sqlite3)..."
case "$OS" in
  ubuntu|debian|linuxmint|pop)
    $SUDO apt-get install -y curl wget git ffmpeg jq sqlite3
    ;;
  fedora|rhel|centos|rocky|almalinux)
    $SUDO dnf install -y curl wget git ffmpeg jq sqlite
    ;;
  arch|manjaro)
    $SUDO pacman -S --noconfirm curl wget git ffmpeg jq sqlite
    ;;
esac
echo -e "${GREEN}✓ System utilities installed${NC}"
echo ""

# Install NVIDIA Container Toolkit (if GPU detected)
echo "Checking for NVIDIA GPU..."
if command -v nvidia-smi >/dev/null 2>&1; then
  echo -e "${GREEN}✓ NVIDIA GPU detected${NC}"
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
  echo ""

  # Check if NVIDIA Container Toolkit is installed
  if docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
    echo -e "${GREEN}✓ NVIDIA Container Toolkit already configured${NC}"
  else
    echo "Installing NVIDIA Container Toolkit..."
    case "$OS" in
      ubuntu|debian|linuxmint|pop)
        # Add NVIDIA repository
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        if [[ "$OS" == "linuxmint" || "$OS" == "pop" ]]; then
          # Map to Ubuntu version
          if [[ "${VER%%.*}" -ge 21 ]]; then
            distribution="ubuntu22.04"
          else
            distribution="ubuntu20.04"
          fi
        fi

        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | $SUDO gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
          sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
          $SUDO tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

        $SUDO apt-get update
        $SUDO apt-get install -y nvidia-container-toolkit
        ;;

      fedora|rhel|centos|rocky|almalinux)
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | \
          $SUDO tee /etc/yum.repos.d/nvidia-container-toolkit.repo
        $SUDO dnf install -y nvidia-container-toolkit
        ;;
    esac

    # Configure Docker to use NVIDIA runtime
    $SUDO nvidia-ctk runtime configure --runtime=docker
    $SUDO systemctl restart docker

    echo -e "${GREEN}✓ NVIDIA Container Toolkit installed${NC}"
  fi
else
  echo -e "${YELLOW}⚠ No NVIDIA GPU detected${NC}"
  echo "  GPU acceleration will not be available."
  echo "  System will use CPU for processing (much slower)."
fi
echo ""

echo -e "${GREEN}✓ All system dependencies installed!${NC}"
echo ""

# Step 1: Run verification
echo "=========================================================================="
echo -e "${BLUE}Step 1: Verifying installation...${NC}"
echo "=========================================================================="
if [[ -f "${REPO_DIR}/scripts/verify_setup.py" ]]; then
  if python3 "${REPO_DIR}/scripts/verify_setup.py"; then
    echo -e "${GREEN}✓ Verification passed${NC}"
  else
    echo -e "${YELLOW}⚠ Some checks failed, but continuing...${NC}"
    sleep 2
  fi
else
  echo -e "${YELLOW}⚠ verify_setup.py not found, skipping verification${NC}"
fi
echo ""

# Step 2: Build Jellyfin plugin (if applicable)
echo -e "${BLUE}Step 2: Building RealTimeHDRSRGAN plugin (if available)...${NC}"
echo "=========================================================================="
JELLYFIN_LIB_DIR="${JELLYFIN_LIB_DIR:-}"
JELLYFIN_PLUGIN_DIR="${JELLYFIN_PLUGIN_DIR:-/var/lib/jellyfin/plugins/RealTimeHDRSRGAN}"

if [[ -z "${JELLYFIN_LIB_DIR}" ]]; then
  for candidate in /usr/lib/jellyfin/bin /usr/share/jellyfin/bin /usr/lib/jellyfin /usr/share/jellyfin; do
    if [[ -f "${candidate}/MediaBrowser.Common.dll" ]]; then
      JELLYFIN_LIB_DIR="${candidate}"
      break
    fi
  done
fi

if [[ -n "${JELLYFIN_LIB_DIR}" ]]; then
  echo "Found Jellyfin at: ${JELLYFIN_LIB_DIR}"
  echo "Building RealTimeHDRSRGAN plugin..."

  # Clear cache and build
  cd "${REPO_DIR}/jellyfin-plugin/Server"
  dotnet nuget locals all --clear
  dotnet restore --force
  dotnet build -c Release "/p:JellyfinLibDir=${JELLYFIN_LIB_DIR}"

  # Install plugin
  echo "Installing plugin to: ${JELLYFIN_PLUGIN_DIR}"
  if ! $SUDO mkdir -p "${JELLYFIN_PLUGIN_DIR}"; then
    echo -e "${RED}✗ Failed to create plugin directory: ${JELLYFIN_PLUGIN_DIR}${NC}" >&2
    exit 1
  fi

  PLUGIN_OUTPUT_DIR=$(find "${REPO_DIR}/jellyfin-plugin/Server/bin/Release" -maxdepth 1 -type d -name "net*" | head -1)
  if [[ -z "${PLUGIN_OUTPUT_DIR}" ]]; then
    echo -e "${YELLOW}⚠ Plugin build output not found, skipping copy${NC}" >&2
  else
    $SUDO cp "${PLUGIN_OUTPUT_DIR}/"* "${JELLYFIN_PLUGIN_DIR}/"
    $SUDO chown -R jellyfin:jellyfin "${JELLYFIN_PLUGIN_DIR}"
    $SUDO chmod 644 "${JELLYFIN_PLUGIN_DIR}/"*.dll 2>/dev/null || true
    $SUDO chmod 755 "${JELLYFIN_PLUGIN_DIR}/"*.sh 2>/dev/null || true
    echo -e "${GREEN}✓ RealTimeHDRSRGAN plugin installed${NC}"
    echo "  Target: Jellyfin 10.11.5 (.NET 9.0)"
  fi

  # Return to repo directory
  cd "${REPO_DIR}"
else
  echo -e "${YELLOW}⚠ Jellyfin not found, skipping plugin build${NC}"
  echo "  (Plugin can be built manually later if needed)"
fi
echo ""

# Step 2.3: Build and install patched webhook plugin
echo -e "${BLUE}Step 2.3: Building patched Jellyfin webhook plugin...${NC}"
echo "=========================================================================="
WEBHOOK_PLUGIN_SRC="${REPO_DIR}/jellyfin-plugin-webhook"
WEBHOOK_PLUGIN_DIR="/var/lib/jellyfin/plugins/Webhook"

if [[ -d "${WEBHOOK_PLUGIN_SRC}" ]]; then
  echo "Found webhook plugin source at: ${WEBHOOK_PLUGIN_SRC}"
  echo "Building patched webhook plugin with Path variable support..."

  # Clear NuGet cache and restore
  cd "${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook"
  dotnet nuget locals all --clear
  dotnet restore --force

  # Build the project
  if dotnet build -c Release; then
    echo -e "${GREEN}✓ Webhook plugin built successfully${NC}"

    # Find the output directory
    WEBHOOK_OUTPUT_DIR=$(find "${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook/bin/Release" -maxdepth 1 -type d -name "net*" | head -1)

    if [[ -n "${WEBHOOK_OUTPUT_DIR}" ]] && [[ -f "${WEBHOOK_OUTPUT_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
      echo "Installing patched webhook plugin to: ${WEBHOOK_PLUGIN_DIR}"

      # Stop Jellyfin before updating plugin
      if systemctl is-active --quiet jellyfin; then
        echo "Stopping Jellyfin..."
        $SUDO systemctl stop jellyfin
        JELLYFIN_WAS_RUNNING=1
      fi

      # Create directory and copy all DLLs
      if $SUDO mkdir -p "${WEBHOOK_PLUGIN_DIR}"; then
        $SUDO cp "${WEBHOOK_OUTPUT_DIR}"/*.dll "${WEBHOOK_PLUGIN_DIR}/"
        $SUDO chown -R jellyfin:jellyfin "${WEBHOOK_PLUGIN_DIR}" 2>/dev/null || true
        echo -e "${GREEN}✓ Patched webhook plugin installed${NC}"
        echo "  Plugin includes {{Path}} variable support for SRGAN pipeline"

        # Restart Jellyfin if it was running
        if [[ "${JELLYFIN_WAS_RUNNING}" == "1" ]]; then
          echo "Restarting Jellyfin..."
          $SUDO systemctl start jellyfin
          sleep 3
        fi
      else
        echo -e "${RED}✗ Failed to create webhook plugin directory: ${WEBHOOK_PLUGIN_DIR}${NC}" >&2
      fi
    else
      echo -e "${YELLOW}⚠ Webhook plugin DLL not found after build${NC}"
      echo "  Build output directory: ${WEBHOOK_OUTPUT_DIR}"
    fi
  else
    echo -e "${YELLOW}⚠ Webhook plugin build failed${NC}"
    echo "  This is required for {{Path}} variable support."
    echo "  Try building manually:"
    echo "    cd ${WEBHOOK_PLUGIN_SRC}"
    echo "    ./build-plugin.sh"
  fi

  # Return to repo directory
  cd "${REPO_DIR}"

else
  echo -e "${YELLOW}⚠ Webhook plugin source not found at: ${WEBHOOK_PLUGIN_SRC}${NC}"
  echo "  The patched webhook plugin is required for {{Path}} variable support."
  echo "  The standard Jellyfin webhook plugin does NOT expose file paths."
fi
echo ""

# Step 2.5: Install Jellyfin web overlay files
echo -e "${BLUE}Step 2.5: Installing Jellyfin progress overlay...${NC}"
echo "=========================================================================="
JELLYFIN_WEB_DIR="${JELLYFIN_WEB_DIR:-/usr/share/jellyfin/web}"

if [[ -d "${JELLYFIN_WEB_DIR}" ]]; then
  echo "Found Jellyfin web directory at: ${JELLYFIN_WEB_DIR}"

  # Copy CSS files
  if [[ -f "${REPO_DIR}/jellyfin-plugin/playback-progress-overlay.css" ]]; then
    echo "Installing progress overlay CSS..."
    sudo cp "${REPO_DIR}/jellyfin-plugin/playback-progress-overlay.css" "${JELLYFIN_WEB_DIR}/"
    echo -e "${GREEN}✓ playback-progress-overlay.css installed${NC}"
  else
    echo -e "${YELLOW}⚠ playback-progress-overlay.css not found${NC}"
  fi

  # Copy JavaScript file
  if [[ -f "${REPO_DIR}/jellyfin-plugin/playback-progress-overlay.js" ]]; then
    echo "Installing progress overlay JavaScript..."
    sudo cp "${REPO_DIR}/jellyfin-plugin/playback-progress-overlay.js" "${JELLYFIN_WEB_DIR}/"
    echo -e "${GREEN}✓ playback-progress-overlay.js installed${NC}"
  else
    echo -e "${YELLOW}⚠ playback-progress-overlay.js not found${NC}"
  fi

  # Copy optional centered CSS variant
  if [[ -f "${REPO_DIR}/jellyfin-plugin/playback-progress-overlay-centered.css" ]]; then
    echo "Installing centered overlay variant (optional)..."
    sudo cp "${REPO_DIR}/jellyfin-plugin/playback-progress-overlay-centered.css" "${JELLYFIN_WEB_DIR}/"
    echo -e "${GREEN}✓ playback-progress-overlay-centered.css installed${NC}"
  fi

  echo ""
  echo "Overlay files installed to: ${JELLYFIN_WEB_DIR}"
  echo "Restart Jellyfin and refresh browser to see changes."
  echo ""
else
  echo -e "${YELLOW}⚠ Jellyfin web directory not found at: ${JELLYFIN_WEB_DIR}${NC}"
  echo "  Set JELLYFIN_WEB_DIR environment variable if Jellyfin is in a different location."
  echo "  You can copy files manually:"
  echo "    sudo cp ${REPO_DIR}/jellyfin-plugin/playback-progress-overlay.* ${JELLYFIN_WEB_DIR}/"
fi
echo ""

# Step 3: Setup model files (optional)
echo -e "${BLUE}Step 3: Setting up AI model (optional)...${NC}"
echo "=========================================================================="
MODEL_DIR="${REPO_DIR}/models"
mkdir -p "${MODEL_DIR}"

# Check if model setup script exists and run it
if [[ -f "${REPO_DIR}/scripts/setup_model.sh" ]]; then
  # Check if model already exists
  if [[ -f "${MODEL_DIR}/swift_srgan_4x.pth" ]]; then
    echo -e "${GREEN}✓ Model file swift_srgan_4x.pth already exists${NC}"
  elif [[ -f "${MODEL_DIR}/swift_srgan_4x.pth.tar" ]]; then
    echo "Found swift_srgan_4x.pth.tar, renaming to .pth..."
    mv "${MODEL_DIR}/swift_srgan_4x.pth.tar" "${MODEL_DIR}/swift_srgan_4x.pth"
    echo -e "${GREEN}✓ Model file renamed${NC}"
  else
    # Model doesn't exist, ask user if they want to download
    echo "AI model not found."
    echo ""
    echo "The AI model is optional - the pipeline works with ffmpeg upscaling by default."
    echo "Model is only needed if you set SRGAN_ENABLE=1 in docker-compose.yml."
    echo ""
    read -p "Download AI model now? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      bash "${REPO_DIR}/scripts/setup_model.sh"
    else
      echo -e "${YELLOW}⚠ Skipping model download${NC}"
      echo "  Download later with: ./scripts/setup_model.sh"
    fi
  fi
else
  # Fallback: simple model check
  if [[ -f "${MODEL_DIR}/swift_srgan_4x.pth.tar" ]]; then
    if [[ ! -f "${MODEL_DIR}/swift_srgan_4x.pth" ]]; then
      echo "Renaming swift_srgan_4x.pth.tar to swift_srgan_4x.pth..."
      mv "${MODEL_DIR}/swift_srgan_4x.pth.tar" "${MODEL_DIR}/swift_srgan_4x.pth"
      echo -e "${GREEN}✓ Model file renamed${NC}"
    fi
  elif [[ -f "${MODEL_DIR}/swift_srgan_4x.pth" ]]; then
    echo -e "${GREEN}✓ Model file found${NC}"
  else
    echo -e "${YELLOW}⚠ Model file not found (optional)${NC}"
    echo "  Download from: https://github.com/Koushik0901/Swift-SRGAN/releases/download/v0.1/swift_srgan_4x.pth.tar"
    echo "  Or run: ./scripts/setup_model.sh"
  fi
fi
echo ""

# Step 4: Build Docker images
echo -e "${BLUE}Step 4: Building Docker images...${NC}"
echo "=========================================================================="
docker compose -f "${REPO_DIR}/docker-compose.yml" build
echo -e "${GREEN}✓ Docker images built${NC}"
echo ""

# Step 5: Start container
echo -e "${BLUE}Step 5: Starting srgan-upscaler container...${NC}"
echo "=========================================================================="
docker compose -f "${REPO_DIR}/docker-compose.yml" up -d srgan-upscaler
echo -e "${GREEN}✓ Container started${NC}"
echo ""

# Step 6: Optional GPU detection
if [[ "${RUN_GPU_DETECTION:-1}" == "1" ]]; then
  echo -e "${BLUE}Step 6: Running GPU detection...${NC}"
  echo "=========================================================================="
  if bash "${REPO_DIR}/jellyfin-plugin/gpu-detection.sh"; then
    echo -e "${GREEN}✓ GPU detection completed${NC}"
  else
    echo -e "${YELLOW}⚠ GPU detection failed (non-critical)${NC}"
  fi
  echo ""
else
  echo -e "${YELLOW}Skipping GPU detection (set RUN_GPU_DETECTION=1 to enable)${NC}"
  echo ""
fi

# Step 7: Optional cleanup
if [[ "${RUN_CLEANUP:-0}" == "1" ]]; then
  echo -e "${BLUE}Step 7: Cleaning up old upscaled files...${NC}"
  echo "=========================================================================="
  if python3 "${REPO_DIR}/scripts/cleanup_upscaled.py"; then
    echo -e "${GREEN}✓ Cleanup completed${NC}"
  else
    echo -e "${YELLOW}⚠ Cleanup failed (non-critical)${NC}"
  fi
  echo ""
fi

# Step 8: Install systemd watchdog service
echo -e "${BLUE}Step 8: Installing watchdog systemd service...${NC}"
echo "=========================================================================="
if $SUDO bash "${REPO_DIR}/scripts/install_systemd_watchdog.sh" "${REPO_DIR}"; then
  echo -e "${GREEN}✓ Watchdog service installed and started${NC}"
else
  echo -e "${RED}✗ Watchdog service installation failed${NC}"
  echo "  You can try installing manually:"
  echo "  sudo ./scripts/install_systemd_watchdog.sh"
  exit 1
fi
echo ""

# Step 9: Configure webhook plugin
echo -e "${BLUE}Step 9: Configuring Jellyfin webhook plugin...${NC}"
echo "=========================================================================="
WEBHOOK_CONFIG_PATH="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"

if [[ -f "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
  echo "Patched webhook plugin detected, configuring for SRGAN pipeline..."

  # Wait for webhook service to be ready
  sleep 2

  # Configure webhook using Python script
  if [[ -f "${REPO_DIR}/scripts/configure_webhook.py" ]]; then
    if $SUDO python3 "${REPO_DIR}/scripts/configure_webhook.py" "http://localhost:5000" "${WEBHOOK_CONFIG_PATH}"; then
      echo -e "${GREEN}✓ Webhook configured successfully${NC}"
      echo "  Webhook will trigger on: PlaybackStart"
      echo "  Target endpoint: http://localhost:5000/upscale-trigger"

      # Restart Jellyfin to load webhook configuration
      if systemctl is-active --quiet jellyfin; then
        echo "Restarting Jellyfin to apply webhook configuration..."
        $SUDO systemctl restart jellyfin
        echo -e "${GREEN}✓ Jellyfin restarted${NC}"
      fi
    else
      echo -e "${YELLOW}⚠ Webhook configuration failed (non-critical)${NC}"
      echo "  You can configure manually via Jellyfin Dashboard → Plugins → Webhook"
    fi
  else
    echo -e "${YELLOW}⚠ configure_webhook.py not found${NC}"
    echo "  Configure webhook manually via Jellyfin Dashboard"
  fi
else
  echo -e "${YELLOW}⚠ Patched webhook plugin not installed${NC}"
  echo "  Configure webhook manually via Jellyfin Dashboard → Plugins → Webhook"
  echo "  Make sure to include {{Path}} in your template"
fi
echo ""

# Step 10: Fix Jellyfin permissions
echo -e "${BLUE}Step 10: Fixing Jellyfin permissions...${NC}"
echo "=========================================================================="
JELLYFIN_DATA_DIR="/var/lib/jellyfin"

if [[ -d "${JELLYFIN_DATA_DIR}" ]]; then
  echo "Setting correct ownership and permissions for ${JELLYFIN_DATA_DIR}..."

  # Set ownership to jellyfin:jellyfin recursively
  echo "  → Setting ownership (jellyfin:jellyfin)..."
  $SUDO chown -R jellyfin:jellyfin "${JELLYFIN_DATA_DIR}" 2>/dev/null || true

  # Fix directory permissions (755 - rwxr-xr-x)
  echo "  → Setting directory permissions (755)..."
  $SUDO find "${JELLYFIN_DATA_DIR}" -type d -exec chmod 755 {} \; 2>/dev/null || true

  # Fix file permissions (644 - rw-r--r--)
  echo "  → Setting file permissions (644)..."
  $SUDO find "${JELLYFIN_DATA_DIR}" -type f -exec chmod 644 {} \; 2>/dev/null || true

  # Make shell scripts executable (755)
  echo "  → Setting script permissions (755)..."
  $SUDO find "${JELLYFIN_DATA_DIR}/plugins" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true

  echo -e "${GREEN}✓ Jellyfin permissions fixed${NC}"

  # Verify plugin directories
  echo ""
  echo "Verifying plugin directories:"
  for plugin_dir in "${JELLYFIN_DATA_DIR}/plugins"/*; do
    if [[ -d "${plugin_dir}" ]]; then
      plugin_name=$(basename "${plugin_dir}")
      owner=$($SUDO stat -c '%U:%G' "${plugin_dir}" 2>/dev/null || $SUDO stat -f '%Su:%Sg' "${plugin_dir}" 2>/dev/null || echo "unknown")
      perms=$($SUDO stat -c '%a' "${plugin_dir}" 2>/dev/null || $SUDO stat -f '%A' "${plugin_dir}" 2>/dev/null || echo "unknown")
      echo "  ${plugin_name}: ${owner} (${perms})"
    fi
  done
else
  echo -e "${YELLOW}⚠ Jellyfin data directory not found at ${JELLYFIN_DATA_DIR}${NC}"
fi
echo ""

# Step 11: Final Jellyfin restart
echo -e "${BLUE}Step 11: Restarting Jellyfin service...${NC}"
echo "=========================================================================="

if systemctl list-unit-files | grep -q jellyfin.service; then
  echo "Restarting Jellyfin to apply all changes..."

  $SUDO systemctl restart jellyfin

  # Wait for Jellyfin to start
  echo "Waiting for Jellyfin to start..."
  sleep 5

  if systemctl is-active --quiet jellyfin; then
    echo -e "${GREEN}✓ Jellyfin service is running${NC}"

    # Show Jellyfin status
    jellyfin_status=$($SUDO systemctl status jellyfin --no-pager -l 2>&1 | head -10)
    echo ""
    echo "Jellyfin Status:"
    echo "${jellyfin_status}" | grep -E "(Active:|Main PID:|Memory:|CPU:)" || echo "  Running"
  else
    echo -e "${YELLOW}⚠ Jellyfin service may not have started properly${NC}"
    echo "  Check logs: sudo journalctl -u jellyfin -n 50"
  fi
else
  echo -e "${YELLOW}⚠ Jellyfin service not found${NC}"
  echo "  If running in Docker, restart manually:"
  echo "  docker restart jellyfin"
fi
echo ""

# Installation complete
echo "=========================================================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "=========================================================================="
echo ""
echo "What was installed:"
echo "  ✓ Docker container (srgan-upscaler)"
echo "  ✓ Watchdog systemd service (auto-starts on boot)"
if [[ -n "${JELLYFIN_LIB_DIR}" ]]; then
  echo "  ✓ Jellyfin plugin"
fi
if [[ -d "${WEBHOOK_PLUGIN_SRC}" ]] && [[ -f "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
  echo "  ✓ Patched webhook plugin (with {{Path}} variable)"
fi
if [[ -d "${JELLYFIN_WEB_DIR}" ]] && [[ -f "${JELLYFIN_WEB_DIR}/playback-progress-overlay.css" ]]; then
  echo "  ✓ Progress overlay (CSS/JS)"
fi
if [[ -f "${MODEL_DIR}/swift_srgan_4x.pth" ]]; then
  echo "  ✓ AI model (optional)"
fi
echo ""
echo "Service Status:"
if systemctl is-active --quiet srgan-watchdog.service; then
  echo -e "  Watchdog: ${GREEN}running${NC} ✓"
else
  echo -e "  Watchdog: ${YELLOW}check status${NC}"
fi
if docker compose -f "${REPO_DIR}/docker-compose.yml" ps | grep -q "srgan-upscaler"; then
  echo -e "  Container: ${GREEN}running${NC} ✓"
else
  echo -e "  Container: ${YELLOW}check status${NC}"
fi
echo ""
echo "Next Steps:"
echo "  1. Hard-refresh your browser to load progress overlay:"
echo "     Ctrl+Shift+R (or Cmd+Shift+R on Mac)"
echo ""
echo "  2. Verify webhook configuration in Jellyfin Dashboard:"
echo "     See: ${REPO_DIR}/WEBHOOK_CONFIGURATION_CORRECT.md"
echo ""
echo "  3. Test the pipeline by playing a video in Jellyfin"
echo "     (Watchdog will log activity to /var/log/srgan-watchdog.log)"
echo ""
echo "  4. Check service status:"
echo "     ${REPO_DIR}/scripts/manage_watchdog.sh status"
echo ""
echo "  5. View logs:"
echo "     ${REPO_DIR}/scripts/manage_watchdog.sh logs"
echo ""
echo "Documentation:"
echo "  Getting Started: ${REPO_DIR}/GETTING_STARTED.md"
echo "  Webhook Setup:   ${REPO_DIR}/WEBHOOK_CONFIGURATION_CORRECT.md"
echo "  Service Mgmt:    ${REPO_DIR}/SYSTEMD_SERVICE.md"
echo "  Troubleshoot:    ${REPO_DIR}/TROUBLESHOOTING.md"
echo ""
echo "Quick health check:"
if curl -s http://localhost:5000/health > /dev/null 2>&1; then
  echo -e "  Webhook: ${GREEN}responding${NC} ✓"
else
  echo -e "  Webhook: ${YELLOW}not responding yet${NC} (may need a few seconds)"
fi
echo ""
