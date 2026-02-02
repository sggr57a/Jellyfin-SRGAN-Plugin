#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Initialize variables that may not be set
WEBHOOK_PLUGIN_DIR=""

echo "=========================================================================="
echo "Real-Time HDR SRGAN Pipeline - Automated Installation"
echo "=========================================================================="
echo ""

# Helper function to check if running as root/sudo
check_sudo() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Running as root. Some installations may need regular user context.${NC}"
  fi
}

# Helper function to detect OS
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID}"
    OS_VERSION="${VERSION_ID}"
    echo -e "${BLUE}Detected OS: ${NAME} ${VERSION_ID}${NC}"
  else
    echo -e "${RED}Cannot detect OS. This script supports Ubuntu/Debian.${NC}"
    exit 1
  fi
}

# Step 0: Install system dependencies
echo -e "${BLUE}Step 0: Installing system dependencies...${NC}"
echo "=========================================================================="
detect_os

# Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
  if [[ "${OS_ID}" == "ubuntu" ]] || [[ "${OS_ID}" == "debian" ]]; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker "${USER}"
    rm /tmp/get-docker.sh
    echo -e "${GREEN}✓ Docker installed${NC}"
    echo -e "${YELLOW}⚠ You may need to log out and back in for group changes to take effect${NC}"
    echo "  Or run: newgrp docker"
  else
    echo -e "${RED}Unsupported OS for automatic Docker installation: ${OS_ID}${NC}"
    echo "Please install Docker manually: https://docs.docker.com/engine/install/"
    exit 1
  fi
else
  echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Verify Docker Compose v2
if ! docker compose version >/dev/null 2>&1; then
  echo -e "${YELLOW}Docker Compose v2 not found${NC}"
  if docker-compose version >/dev/null 2>&1; then
    echo -e "${YELLOW}Legacy docker-compose detected. Docker Compose v2 is required.${NC}"
    echo "Please upgrade Docker to get Compose v2: https://docs.docker.com/compose/install/"
    exit 1
  else
    echo -e "${RED}Docker Compose v2 not available${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✓ Docker Compose v2 available${NC}"
fi

# Install Python and Flask if missing
if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${YELLOW}Python 3 not found. Installing...${NC}"
  sudo apt-get update
  sudo apt-get install -y python3 python3-pip
  echo -e "${GREEN}✓ Python 3 installed${NC}"
else
  echo -e "${GREEN}✓ Python 3 already installed${NC}"
fi

# Install Flask and requests
echo "Checking Python dependencies (Flask, requests)..."
if ! python3 -c "import flask" >/dev/null 2>&1 || ! python3 -c "import requests" >/dev/null 2>&1; then
  echo -e "${YELLOW}Installing Flask and requests...${NC}"
  pip3 install flask requests
  echo -e "${GREEN}✓ Flask and requests installed${NC}"
else
  echo -e "${GREEN}✓ Flask and requests already installed${NC}"
fi

# Install .NET 9.0 SDK and Runtime
if ! command -v dotnet >/dev/null 2>&1; then
  echo -e "${YELLOW}.NET SDK not found. Installing .NET 9.0...${NC}"
  if [[ "${OS_ID}" == "ubuntu" ]]; then
    wget https://packages.microsoft.com/config/ubuntu/${OS_VERSION}/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
    sudo dpkg -i /tmp/packages-microsoft-prod.deb
    rm /tmp/packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y dotnet-sdk-9.0 aspnetcore-runtime-9.0
    echo -e "${GREEN}✓ .NET 9.0 SDK and Runtime installed${NC}"
  elif [[ "${OS_ID}" == "debian" ]]; then
    wget https://packages.microsoft.com/config/debian/${OS_VERSION}/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
    sudo dpkg -i /tmp/packages-microsoft-prod.deb
    rm /tmp/packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y dotnet-sdk-9.0 aspnetcore-runtime-9.0
    echo -e "${GREEN}✓ .NET 9.0 SDK and Runtime installed${NC}"
  else
    echo -e "${YELLOW}⚠ Unsupported OS for automatic .NET installation${NC}"
    echo "Please install .NET 9.0 manually: https://dotnet.microsoft.com/download"
  fi
else
  echo -e "${GREEN}✓ .NET SDK already installed ($(dotnet --version))${NC}"
fi

# Check for NVIDIA GPU and drivers
echo "Checking for NVIDIA GPU..."
if command -v nvidia-smi >/dev/null 2>&1; then
  echo -e "${GREEN}✓ NVIDIA drivers installed${NC}"
  nvidia-smi --query-gpu=name --format=csv,noheader | head -1
else
  echo -e "${YELLOW}⚠ NVIDIA drivers not detected${NC}"
  echo "Please install NVIDIA drivers for your GPU: https://www.nvidia.com/Download/index.aspx"
  echo "This is required for GPU-accelerated upscaling."
  read -p "Continue without GPU support? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Install NVIDIA Container Toolkit if GPU is available
if command -v nvidia-smi >/dev/null 2>&1; then
  if ! docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
    echo -e "${YELLOW}NVIDIA Container Toolkit not found. Installing...${NC}"
    if [[ "${OS_ID}" == "ubuntu" ]] || [[ "${OS_ID}" == "debian" ]]; then
      distribution="${OS_ID}${OS_VERSION}"
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
      curl -s -L https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
      sudo apt-get update
      sudo apt-get install -y nvidia-container-toolkit
      sudo systemctl restart docker
      echo -e "${GREEN}✓ NVIDIA Container Toolkit installed${NC}"
    else
      echo -e "${YELLOW}⚠ Unsupported OS for automatic NVIDIA Container Toolkit installation${NC}"
      echo "Please install manually: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
    fi
  else
    echo -e "${GREEN}✓ NVIDIA Container Toolkit already installed${NC}"
  fi
fi

# Check for Jellyfin server (do not install)
echo "Checking for Jellyfin server..."
JELLYFIN_FOUND=false
if systemctl is-active --quiet jellyfin 2>/dev/null; then
  echo -e "${GREEN}✓ Jellyfin server is running${NC}"
  JELLYFIN_FOUND=true
elif command -v jellyfin >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ Jellyfin is installed but not running${NC}"
  JELLYFIN_FOUND=true
else
  echo -e "${YELLOW}⚠ Jellyfin server not detected${NC}"
  echo "The plugin requires Jellyfin 10.8+ to be installed."
  echo "Install from: https://jellyfin.org/downloads/"
  echo ""
  read -p "Continue without Jellyfin? (plugin installation will be skipped) (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo ""

# Step 1: Run verification
echo -e "${BLUE}Step 1: Verifying system prerequisites...${NC}"
echo "=========================================================================="
if [[ -f "${REPO_DIR}/scripts/verify_setup.py" ]]; then
  if python3 "${REPO_DIR}/scripts/verify_setup.py"; then
    echo -e "${GREEN}✓ Verification passed${NC}"
  else
    echo -e "${YELLOW}⚠ Some checks failed but dependencies are installed${NC}"
    echo "  Continuing with installation..."
    sleep 2
  fi
else
  echo -e "${YELLOW}⚠ verify_setup.py not found, skipping verification${NC}"
fi
echo ""

# Step 2: Build and Install Jellyfin Plugins
echo -e "${BLUE}Step 2: Building and installing Jellyfin plugins...${NC}"
echo "=========================================================================="

# Find Jellyfin library directory for compilation
JELLYFIN_LIB_DIR="${JELLYFIN_LIB_DIR:-}"
if [[ -z "${JELLYFIN_LIB_DIR}" ]]; then
  for candidate in /usr/lib/jellyfin/bin /usr/share/jellyfin/bin /usr/lib/jellyfin /usr/share/jellyfin; do
    if [[ -f "${candidate}/MediaBrowser.Common.dll" ]]; then
      JELLYFIN_LIB_DIR="${candidate}"
      break
    fi
  done
fi

PLUGINS_BASE_DIR="/var/lib/jellyfin/plugins"
JELLYFIN_NEEDS_RESTART=false

# --- SRGAN Plugin Build & Install ---
echo ""
echo "Building Real-Time HDR SRGAN Plugin..."
if [[ -n "${JELLYFIN_LIB_DIR}" ]]; then
  echo "  Using Jellyfin libraries from: ${JELLYFIN_LIB_DIR}"
  
  # Clean and build
  dotnet clean "${REPO_DIR}/jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj" >/dev/null 2>&1 || true
  if dotnet build "${REPO_DIR}/jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj" -c Release "/p:JellyfinLibDir=${JELLYFIN_LIB_DIR}"; then
    echo -e "${GREEN}✓ SRGAN plugin built successfully${NC}"
    
    # Find build output
    SRGAN_OUTPUT_DIR=$(find "${REPO_DIR}/jellyfin-plugin/Server/bin/Release" -maxdepth 1 -type d -name "net*" | head -1)
    
    if [[ -n "${SRGAN_OUTPUT_DIR}" && -f "${SRGAN_OUTPUT_DIR}/Jellyfin.Plugin.RealTimeHdrSrgan.dll" ]]; then
      # Find or create plugin directory
      SRGAN_PLUGIN_DIR=$(find "${PLUGINS_BASE_DIR}" -maxdepth 1 -type d -name "Real-Time*HDR*SRGAN*" 2>/dev/null | head -1)
      
      if [[ -z "${SRGAN_PLUGIN_DIR}" ]]; then
        echo "  Creating new plugin directory..."
        SRGAN_PLUGIN_DIR="${PLUGINS_BASE_DIR}/Real-Time HDR SRGAN Pipeline_1.0.0.0"
        sudo mkdir -p "${SRGAN_PLUGIN_DIR}"
      fi
      
      echo "  Installing to: ${SRGAN_PLUGIN_DIR}"
      
      # Backup existing DLL if present
      if [[ -f "${SRGAN_PLUGIN_DIR}/Jellyfin.Plugin.RealTimeHdrSrgan.dll" ]]; then
        sudo cp "${SRGAN_PLUGIN_DIR}/Jellyfin.Plugin.RealTimeHdrSrgan.dll" \
                "${SRGAN_PLUGIN_DIR}/Jellyfin.Plugin.RealTimeHdrSrgan.dll.backup"
        echo "    ✓ Backed up existing DLL"
      fi
      
      # Copy all files (DLL + shell scripts)
      sudo cp "${SRGAN_OUTPUT_DIR}/"*.dll "${SRGAN_PLUGIN_DIR}/" 2>/dev/null || true
      sudo cp "${SRGAN_OUTPUT_DIR}/"*.sh "${SRGAN_PLUGIN_DIR}/" 2>/dev/null || true
      sudo chmod +x "${SRGAN_PLUGIN_DIR}/"*.sh 2>/dev/null || true
      
      echo -e "  ${GREEN}✓ SRGAN plugin installed${NC}"
      JELLYFIN_NEEDS_RESTART=true
    else
      echo -e "${YELLOW}⚠ SRGAN plugin build output not found${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ SRGAN plugin build failed${NC}"
    echo "  You can build manually: cd ${REPO_DIR}/jellyfin-plugin/Server && dotnet build -c Release"
  fi
else
  echo -e "${YELLOW}⚠ Jellyfin library directory not found, skipping SRGAN plugin build${NC}"
  echo "  Set JELLYFIN_LIB_DIR environment variable or install Jellyfin first"
fi

# --- Webhook Plugin Build & Install ---
echo ""
echo "=========================================================================="
echo "Setting up Webhook Plugin with {{Path}} Variable Support..."
echo "=========================================================================="
WEBHOOK_PLUGIN_SRC="${REPO_DIR}/jellyfin-plugin-webhook"
WEBHOOK_HELPERS_FILE="${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs"

# Step 2.1: Setup webhook source if needed
if [[ ! -f "${WEBHOOK_HELPERS_FILE}" ]]; then
  echo ""
  echo "Webhook source code not found. Setting up from official repository..."
  if [[ -f "${REPO_DIR}/scripts/setup_webhook_source.sh" ]]; then
    if bash "${REPO_DIR}/scripts/setup_webhook_source.sh"; then
      echo -e "${GREEN}✓ Webhook source setup complete${NC}"
      
      # Verify critical files were created
      if [[ -f "${WEBHOOK_HELPERS_FILE}" ]]; then
        echo "  ✓ DataObjectHelpers.cs found"
      else
        echo -e "${RED}✗ DataObjectHelpers.cs still missing after setup${NC}"
        echo "  Check setup_webhook_source.sh output above"
      fi
    else
      echo -e "${RED}✗ Webhook source setup failed${NC}"
      echo "  Cannot build webhook without source code"
      echo "  See errors above"
    fi
  else
    echo -e "${RED}✗ setup_webhook_source.sh not found at: ${REPO_DIR}/scripts/setup_webhook_source.sh${NC}"
  fi
else
  echo ""
  echo "✓ Webhook source code already present"
fi

# Step 2.2: Apply Path patch if needed
if [[ -f "${WEBHOOK_HELPERS_FILE}" ]]; then
  echo ""
  echo "Checking if {{Path}} patch is applied..."
  if ! grep -q '"Path".*item\.Path' "${WEBHOOK_HELPERS_FILE}"; then
    echo "{{Path}} patch not found. Applying patch..."
    if [[ -f "${REPO_DIR}/scripts/patch_webhook_path.sh" ]]; then
      if bash "${REPO_DIR}/scripts/patch_webhook_path.sh"; then
        echo -e "${GREEN}✓ {{Path}} patch applied successfully${NC}"
        
        # Verify patch
        if grep -q '"Path".*item\.Path' "${WEBHOOK_HELPERS_FILE}"; then
          echo "  Verified: Path property found in source"
        else
          echo -e "${RED}✗ Patch verification failed!${NC}"
          echo "  Check ${WEBHOOK_HELPERS_FILE}"
        fi
      else
        echo -e "${RED}✗ Patch application failed${NC}"
        echo "  Webhook will not include Path variable"
      fi
    else
      echo -e "${YELLOW}⚠ patch_webhook_path.sh not found${NC}"
    fi
  else
    echo -e "${GREEN}✓ {{Path}} patch already applied${NC}"
    echo "  Current implementation:"
    grep -A 3 -B 1 '"Path".*item\.Path' "${WEBHOOK_HELPERS_FILE}" | head -5 | sed 's/^/  /'
  fi
fi

# Step 2.3: Build webhook plugin
echo ""
echo "Building Patched Webhook Plugin..."

if [[ -d "${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook" ]]; then
  # Use .csproj directly (no .sln file in our setup)
  WEBHOOK_CSPROJ="${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook/Jellyfin.Plugin.Webhook.csproj"
  
  if [[ ! -f "${WEBHOOK_CSPROJ}" ]]; then
    echo -e "${RED}✗ Webhook project file not found: ${WEBHOOK_CSPROJ}${NC}"
    echo "  Run setup_webhook_source.sh first"
  else
    # Clean previous build
    echo "Cleaning previous webhook build..."
    cd "${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook"
    rm -rf bin obj 2>/dev/null || true
    dotnet nuget locals all --clear >/dev/null 2>&1 || true
    
    # Build
    echo "Building webhook plugin from: ${WEBHOOK_CSPROJ}"
    if dotnet build "${WEBHOOK_CSPROJ}" -c Release; then
    echo -e "${GREEN}✓ Webhook plugin built successfully${NC}"
    
    # Find build output directory
    WEBHOOK_OUTPUT_DIR=$(find "${WEBHOOK_PLUGIN_SRC}" -path "*/bin/Release/net*" -type d | head -1)
    
    if [[ -n "${WEBHOOK_OUTPUT_DIR}" && -f "${WEBHOOK_OUTPUT_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
      # Find existing webhook plugin directory
      WEBHOOK_PLUGIN_DIR=$(find "${PLUGINS_BASE_DIR}" -maxdepth 1 -type d -name "Webhook_*" 2>/dev/null | head -1)
      
      if [[ -z "${WEBHOOK_PLUGIN_DIR}" ]]; then
        echo -e "${YELLOW}⚠ Webhook plugin not installed in Jellyfin${NC}"
        echo "  Install the webhook plugin from Jellyfin Dashboard → Plugins → Catalog first"
        echo "  Then run this script again to patch it with Path support"
      else
        echo "  Installing to: ${WEBHOOK_PLUGIN_DIR}"
        
        # Backup existing DLL
        if [[ -f "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
          sudo cp "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" \
                  "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll.backup"
          echo "    ✓ Backed up existing DLL"
        fi
        
        # Copy ALL files from build output (DLL + dependencies + deps.json)
        echo "  Copying plugin files and dependencies..."
        echo "    From: ${WEBHOOK_OUTPUT_DIR}"
        echo "    To:   ${WEBHOOK_PLUGIN_DIR}"
        echo ""
        
        # List files to be copied
        echo "  Files to copy:"
        for dll in "${WEBHOOK_OUTPUT_DIR}"/*.dll; do
          if [[ -f "$dll" ]]; then
            FILENAME=$(basename "$dll")
            SIZE=$(du -h "$dll" | cut -f1)
            echo "    - ${FILENAME} (${SIZE})"
          fi
        done
        
        # Copy DLLs
        sudo cp "${WEBHOOK_OUTPUT_DIR}/"*.dll "${WEBHOOK_PLUGIN_DIR}/" 2>/dev/null || true
        
        # Copy deps.json
        if [[ -f "${WEBHOOK_OUTPUT_DIR}/Jellyfin.Plugin.Webhook.deps.json" ]]; then
          sudo cp "${WEBHOOK_OUTPUT_DIR}/Jellyfin.Plugin.Webhook.deps.json" "${WEBHOOK_PLUGIN_DIR}/"
          echo "    ✓ deps.json copied"
        fi
        
        # Set correct ownership and permissions
        echo ""
        echo "  Setting permissions..."
        sudo chown jellyfin:jellyfin "${WEBHOOK_PLUGIN_DIR}"/*.dll 2>/dev/null || true
        sudo chmod 644 "${WEBHOOK_PLUGIN_DIR}"/*.dll 2>/dev/null || true
        
        # Verify critical files were copied
        echo ""
        echo "  Verifying installation..."
        VERIFY_FILES=(
          "Jellyfin.Plugin.Webhook.dll"
          "Handlebars.Net.dll"
          "MailKit.dll"
        )
        
        ALL_PRESENT=true
        for file in "${VERIFY_FILES[@]}"; do
          if [[ -f "${WEBHOOK_PLUGIN_DIR}/${file}" ]]; then
            echo "    ✓ ${file}"
          else
            echo "    ✗ ${file} - MISSING!"
            ALL_PRESENT=false
          fi
        done
        
        if $ALL_PRESENT; then
          echo ""
          echo -e "  ${GREEN}✓ Patched webhook plugin installed with Path support${NC}"
          JELLYFIN_NEEDS_RESTART=true
        else
          echo ""
          echo -e "  ${YELLOW}⚠ Some files may be missing${NC}"
        fi
      fi
    else
      echo -e "${YELLOW}⚠ Webhook plugin build output not found${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ Webhook plugin build failed${NC}"
    echo "  Check build output above for errors"
    echo "  You can build manually: cd ${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook && dotnet build -c Release"
  fi
  fi
else
  echo -e "${YELLOW}⚠ Webhook plugin source not found at: ${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook${NC}"
  echo "  The patched webhook plugin is required for {{Path}} variable support"
  echo "  Run: ./scripts/setup_webhook_source.sh"
fi

# Restart Jellyfin if plugins were installed
if [[ "${JELLYFIN_NEEDS_RESTART}" == "true" ]]; then
  echo ""
  echo "=========================================================================="
  echo "Restarting Jellyfin to load new plugins..."
  if systemctl is-active --quiet jellyfin 2>/dev/null; then
    sudo systemctl restart jellyfin
    echo -e "${GREEN}✓ Jellyfin restarted${NC}"
    echo "  Waiting 10 seconds for Jellyfin to initialize..."
    sleep 10
    if systemctl is-active --quiet jellyfin; then
      echo -e "${GREEN}✓ Jellyfin is running${NC}"
    else
      echo -e "${YELLOW}⚠ Jellyfin may not have started correctly${NC}"
      echo "  Check logs: sudo journalctl -u jellyfin -n 50"
    fi
  else
    echo -e "${YELLOW}⚠ Jellyfin service not detected${NC}"
    echo "  Restart Jellyfin manually to load the new plugins"
  fi
fi
echo ""

# Step 2.4: Configure webhook for SRGAN pipeline
echo -e "${BLUE}Step 2.4: Configuring webhook for SRGAN pipeline...${NC}"
echo "=========================================================================="
WEBHOOK_CONFIG_PATH="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"
WATCHDOG_URL="${WATCHDOG_URL:-http://localhost:5000}"

if [[ -f "${REPO_DIR}/scripts/configure_webhook.py" ]]; then
  echo "Configuring webhook to trigger upscaling on playback..."
  echo "  Watchdog URL: ${WATCHDOG_URL}"
  echo "  Config file: ${WEBHOOK_CONFIG_PATH}"
  echo ""
  
  if sudo python3 "${REPO_DIR}/scripts/configure_webhook.py" "${WATCHDOG_URL}" "${WEBHOOK_CONFIG_PATH}"; then
    echo ""
    echo -e "${GREEN}✓ Webhook configured successfully${NC}"
    echo "  The webhook will automatically trigger upscaling when playback starts"
    echo "  Restart Jellyfin to load the configuration:"
    echo "    sudo systemctl restart jellyfin"
  else
    echo -e "${YELLOW}⚠ Webhook configuration failed (non-critical)${NC}"
    echo "  You can configure manually through Jellyfin Dashboard → Plugins → Webhooks"
    echo "  Or run: sudo python3 ${REPO_DIR}/scripts/configure_webhook.py ${WATCHDOG_URL}"
  fi
else
  echo -e "${YELLOW}⚠ Webhook configuration script not found${NC}"
  echo "  Manual configuration required through Jellyfin Dashboard → Plugins → Webhooks"
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
if sudo bash "${REPO_DIR}/scripts/install_systemd_watchdog.sh" "${REPO_DIR}"; then
  echo -e "${GREEN}✓ Watchdog service installed and started${NC}"
else
  echo -e "${RED}✗ Watchdog service installation failed${NC}"
  echo "  You can try installing manually:"
  echo "  sudo ./scripts/install_systemd_watchdog.sh"
  exit 1
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
if [[ -d "${WEBHOOK_PLUGIN_SRC}" ]] && [[ -n "${WEBHOOK_PLUGIN_DIR}" ]] && [[ -f "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
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
echo "  1. Restart Jellyfin to load progress overlay:"
echo "     sudo systemctl restart jellyfin"
echo "     Then hard-refresh browser: Ctrl+Shift+R"
echo ""
echo "  2. Configure Jellyfin webhook:"
echo "     See: ${REPO_DIR}/WEBHOOK_CONFIGURATION_CORRECT.md"
echo ""
echo "  3. Test the webhook:"
echo "     python3 ${REPO_DIR}/scripts/test_webhook.py"
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
  echo -e "  Watchdog: ${GREEN}responding${NC} ✓"
else
  echo -e "  Watchdog: ${YELLOW}not responding yet${NC} (may need a few seconds)"
fi
echo ""

# Final {{Path}} verification
echo "=========================================================================="
echo "{{Path}} Variable Verification"
echo "=========================================================================="
WEBHOOK_HELPERS="${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs"
if [[ -f "${WEBHOOK_HELPERS}" ]]; then
  if grep -q '"Path".*item\.Path' "${WEBHOOK_HELPERS}"; then
    echo -e "${GREEN}✓ {{Path}} patch verified in source code${NC}"
  else
    echo -e "${YELLOW}⚠ {{Path}} patch NOT found in source code${NC}"
    echo "  This means Path variable will be empty in webhooks!"
    echo "  Run: sudo ./scripts/fix_webhook_path_complete.sh"
  fi
else
  echo -e "${YELLOW}⚠ Webhook source not available${NC}"
fi

WEBHOOK_CONFIG="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"
if [[ -f "${WEBHOOK_CONFIG}" ]]; then
  if grep -q "{{Path}}" "${WEBHOOK_CONFIG}"; then
    echo -e "${GREEN}✓ {{Path}} found in webhook configuration${NC}"
  else
    echo -e "${YELLOW}⚠ {{Path}} NOT in webhook configuration${NC}"
    echo "  Run: sudo python3 ${REPO_DIR}/scripts/configure_webhook.py http://localhost:5000"
  fi
fi

WEBHOOK_DLL_DIR=$(find /var/lib/jellyfin/plugins -maxdepth 1 -type d -name "Webhook_*" 2>/dev/null | head -1)
if [[ -n "${WEBHOOK_DLL_DIR}" ]] && [[ -f "${WEBHOOK_DLL_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
  DLL_AGE=$(($(date +%s) - $(stat -c %Y "${WEBHOOK_DLL_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -f %m "${WEBHOOK_DLL_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || echo 0)))
  if [[ $DLL_AGE -lt 600 ]]; then
    echo -e "${GREEN}✓ Webhook DLL recently updated ($DLL_AGE seconds ago)${NC}"
  else
    echo -e "${YELLOW}⚠ Webhook DLL is old ($DLL_AGE seconds ago)${NC}"
    echo "  The patched version may not be installed"
  fi
fi
echo ""

exit 0
