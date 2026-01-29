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
echo "Real-Time HDR SRGAN Pipeline - Automated Installation"
echo "=========================================================================="
echo ""

# Step 1: Run verification
echo -e "${BLUE}Step 1: Verifying system prerequisites...${NC}"
echo "=========================================================================="
if [[ -f "${REPO_DIR}/scripts/verify_setup.py" ]]; then
  if python3 "${REPO_DIR}/scripts/verify_setup.py"; then
    echo -e "${GREEN}✓ Verification passed${NC}"
  else
    echo -e "${YELLOW}⚠ Some checks failed. Continuing anyway...${NC}"
    echo "  (You may need to install missing components)"
    sleep 2
  fi
else
  echo -e "${YELLOW}⚠ verify_setup.py not found, skipping verification${NC}"
fi
echo ""

# Basic prerequisites check
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker is not installed or not in PATH.${NC}" >&2
  echo "Please install Docker first: https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker Compose v2 not found. Install or upgrade Docker.${NC}" >&2
  echo "You may be using legacy docker-compose. Upgrade to Docker Compose v2."
  exit 1
fi

# Step 2: Build Jellyfin plugin (if applicable)
echo -e "${BLUE}Step 2: Building Jellyfin plugin (if available)...${NC}"
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
  echo "Building plugin..."
  dotnet build "${REPO_DIR}/jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj" -c Release "/p:JellyfinLibDir=${JELLYFIN_LIB_DIR}"
  echo "Installing plugin to: ${JELLYFIN_PLUGIN_DIR}"
  if ! sudo mkdir -p "${JELLYFIN_PLUGIN_DIR}"; then
    echo -e "${RED}✗ Failed to create plugin directory: ${JELLYFIN_PLUGIN_DIR}${NC}" >&2
    exit 1
  fi
  PLUGIN_OUTPUT_DIR=$(find "${REPO_DIR}/jellyfin-plugin/Server/bin/Release" -maxdepth 1 -type d -name "net*" | head -1)
  if [[ -z "${PLUGIN_OUTPUT_DIR}" ]]; then
    echo -e "${YELLOW}⚠ Plugin build output not found, skipping copy${NC}" >&2
  else
    sudo cp "${PLUGIN_OUTPUT_DIR}/"* "${JELLYFIN_PLUGIN_DIR}/"
    echo -e "${GREEN}✓ Plugin installed${NC}"
  fi
else
  echo -e "${YELLOW}⚠ Jellyfin not found, skipping plugin build${NC}"
  echo "  (Plugin can be built manually later if needed)"
fi
echo ""

# Step 2.3: Build and install patched webhook plugin
echo -e "${BLUE}Step 2.3: Building patched Jellyfin webhook plugin...${NC}"
echo "=========================================================================="
WEBHOOK_PLUGIN_SRC="${REPO_DIR}/jellyfin-plugin-webhook"
WEBHOOK_PLUGIN_DIR="${JELLYFIN_PLUGIN_DIR:-/var/lib/jellyfin/plugins}/Webhook"

if [[ -d "${WEBHOOK_PLUGIN_SRC}" ]]; then
  echo "Found webhook plugin source at: ${WEBHOOK_PLUGIN_SRC}"
  echo "Building patched webhook plugin with Path variable support..."
  
  if dotnet build "${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook.sln" -c Release; then
    echo -e "${GREEN}✓ Webhook plugin built successfully${NC}"
    
    # Find the output DLL
    WEBHOOK_DLL=$(find "${WEBHOOK_PLUGIN_SRC}" -path "*/bin/Release/net*/Jellyfin.Plugin.Webhook.dll" | head -1)
    
    if [[ -n "${WEBHOOK_DLL}" ]]; then
      echo "Installing patched webhook plugin to: ${WEBHOOK_PLUGIN_DIR}"
      if ! sudo mkdir -p "${WEBHOOK_PLUGIN_DIR}"; then
        echo -e "${RED}✗ Failed to create webhook plugin directory: ${WEBHOOK_PLUGIN_DIR}${NC}" >&2
      else
        sudo cp "${WEBHOOK_DLL}" "${WEBHOOK_PLUGIN_DIR}/"
        echo -e "${GREEN}✓ Patched webhook plugin installed${NC}"
        echo "  Restart Jellyfin to load the patched plugin with {{Path}} variable support"
      fi
    else
      echo -e "${YELLOW}⚠ Webhook plugin DLL not found after build${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ Webhook plugin build failed (non-critical)${NC}"
    echo "  You can build manually with: cd ${WEBHOOK_PLUGIN_SRC} && dotnet build -c Release"
  fi
else
  echo -e "${YELLOW}⚠ Webhook plugin source not found at: ${WEBHOOK_PLUGIN_SRC}${NC}"
  echo "  The patched webhook plugin is required for {{Path}} variable support."
  echo "  Clone it with: git clone https://github.com/jellyfin/jellyfin-plugin-webhook.git"
  echo "  Then apply the Path variable patch from WEBHOOK_CONFIGURATION_CORRECT.md"
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
  echo -e "  Webhook: ${GREEN}responding${NC} ✓"
else
  echo -e "  Webhook: ${YELLOW}not responding yet${NC} (may need a few seconds)"
fi
echo ""
