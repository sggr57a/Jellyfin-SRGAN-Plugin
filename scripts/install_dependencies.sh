#!/usr/bin/env bash
set -euo pipefail

# Install System Dependencies for Jellyfin-SRGAN-Plugin
# This script must be run BEFORE install_all.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================================================="
echo "Jellyfin-SRGAN-Plugin - System Dependencies Installation"
echo "=========================================================================="
echo ""
echo "This script will install:"
echo "  - Docker & Docker Compose v2"
echo "  - .NET SDK 9.0"
echo "  - Python 3 & pip"
echo "  - System utilities (ffmpeg, curl, wget, git, jq)"
echo "  - NVIDIA Container Toolkit (if GPU detected)"
echo ""
echo "⚠️  Requires sudo privileges."
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS=$ID
  VER=$VERSION_ID
  echo "Detected: $PRETTY_NAME"
else
  echo -e "${RED}Cannot detect OS${NC}"
  exit 1
fi

SUDO="sudo"
[[ $EUID -eq 0 ]] && SUDO=""

# Update packages
echo "Updating package lists..."
case "$OS" in
  ubuntu|debian|linuxmint|pop)
    $SUDO apt-get update
    ;;
  fedora|rhel|centos|rocky|almalinux)
    $SUDO dnf check-update || true
    ;;
esac
echo -e "${GREEN}✓ Updated${NC}"

# Install Docker
echo "Installing Docker..."
if command -v docker >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Already installed: $(docker --version)${NC}"
else
  case "$OS" in
    ubuntu|debian|linuxmint|pop)
      $SUDO apt-get install -y ca-certificates curl gnupg lsb-release
      $SUDO install -m 0755 -d /etc/apt/keyrings
      [[ ! -f /etc/apt/keyrings/docker.gpg ]] && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
      $SUDO apt-get update
      $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    fedora)
      $SUDO dnf -y install dnf-plugins-core
      $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
  esac
  $SUDO systemctl start docker
  $SUDO systemctl enable docker
  [[ $EUID -ne 0 ]] && $SUDO usermod -aG docker $USER
  echo -e "${GREEN}✓ Installed${NC}"
fi

# Install .NET SDK 9.0
echo "Installing .NET SDK 9.0..."
if dotnet --list-sdks 2>/dev/null | grep -q "9.0"; then
  echo -e "${GREEN}✓ Already installed: $(dotnet --version)${NC}"
else
  case "$OS" in
    ubuntu|linuxmint|pop)
      UBUNTU_VER="22.04"
      [[ "$OS" == "linuxmint" || "$OS" == "pop" ]] && [[ "${VER%%.*}" -lt 21 ]] && UBUNTU_VER="20.04"
      wget -q https://packages.microsoft.com/config/ubuntu/${UBUNTU_VER}/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
      $SUDO dpkg -i /tmp/packages-microsoft-prod.deb
      rm /tmp/packages-microsoft-prod.deb
      $SUDO apt-get update
      $SUDO apt-get install -y dotnet-sdk-9.0
      ;;
    debian)
      wget -q https://packages.microsoft.com/config/debian/${VER}/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
      $SUDO dpkg -i /tmp/packages-microsoft-prod.deb
      rm /tmp/packages-microsoft-prod.deb
      $SUDO apt-get update
      $SUDO apt-get install -y dotnet-sdk-9.0
      ;;
    fedora)
      $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
      wget -q https://packages.microsoft.com/config/fedora/${VER}/prod.repo -O /tmp/microsoft-prod.repo
      $SUDO mv /tmp/microsoft-prod.repo /etc/yum.repos.d/
      $SUDO chown root:root /etc/yum.repos.d/microsoft-prod.repo
      $SUDO dnf install -y dotnet-sdk-9.0
      ;;
  esac
  echo -e "${GREEN}✓ Installed${NC}"
fi

# Install Python 3
echo "Installing Python 3..."
if command -v python3 >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Already installed: $(python3 --version)${NC}"
else
  case "$OS" in
    ubuntu|debian|linuxmint|pop)
      $SUDO apt-get install -y python3 python3-pip python3-venv
      ;;
    fedora|rhel|centos|rocky|almalinux)
      $SUDO dnf install -y python3 python3-pip
      ;;
  esac
  echo -e "${GREEN}✓ Installed${NC}"
fi

# Install utilities
echo "Installing utilities..."
case "$OS" in
  ubuntu|debian|linuxmint|pop)
    $SUDO apt-get install -y curl wget git ffmpeg jq sqlite3
    ;;
  fedora|rhel|centos|rocky|almalinux)
    $SUDO dnf install -y curl wget git ffmpeg jq sqlite
    ;;
esac
echo -e "${GREEN}✓ Installed${NC}"

# NVIDIA Container Toolkit
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "NVIDIA GPU detected. Installing Container Toolkit..."
  if docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Already configured${NC}"
  else
    case "$OS" in
      ubuntu|debian|linuxmint|pop)
        dist="ubuntu22.04"
        [[ "$OS" == "linuxmint" || "$OS" == "pop" ]] && [[ "${VER%%.*}" -lt 21 ]] && dist="ubuntu20.04"
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | $SUDO gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/$dist/libnvidia-container.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | $SUDO tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        $SUDO apt-get update
        $SUDO apt-get install -y nvidia-container-toolkit
        ;;
      fedora|rhel|centos|rocky|almalinux)
        dist=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/libnvidia-container/$dist/libnvidia-container.repo | $SUDO tee /etc/yum.repos.d/nvidia-container-toolkit.repo
        $SUDO dnf install -y nvidia-container-toolkit
        ;;
    esac
    $SUDO nvidia-ctk runtime configure --runtime=docker
    $SUDO systemctl restart docker
    echo -e "${GREEN}✓ Installed${NC}"
  fi
else
  echo -e "${YELLOW}⚠ No NVIDIA GPU detected${NC}"
fi

echo ""
echo -e "${GREEN}=========================================================================="
echo "All dependencies installed successfully!"
echo "==========================================================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Log out and back in (for Docker group membership)"
echo "  2. Run: ./scripts/install_all.sh"
echo ""
