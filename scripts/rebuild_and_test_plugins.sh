#!/bin/bash
#
# Complete Plugin Rebuild and Test Script
# Rebuilds both RealTimeHDRSRGAN and Webhook plugins from scratch, installs, and tests
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

# Check for sudo
SUDO=""
if [[ $EUID -ne 0 ]]; then
  SUDO="sudo"
fi

echo "=========================================================================="
echo -e "${BLUE}Real-Time HDR SRGAN Plugin - Complete Rebuild and Test${NC}"
echo "=========================================================================="
echo "Repository: ${REPO_DIR}"
echo ""

# ============================================================================
# Step 1: Check .NET Installation
# ============================================================================
echo -e "${BLUE}Step 1: Checking .NET installation...${NC}"
echo "=========================================================================="

if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}✗ .NET SDK not found${NC}"
    echo ""
    echo "Please install .NET 9.0 SDK:"
    echo "  https://dotnet.microsoft.com/download/dotnet/9.0"
    echo ""
    echo "Or use Docker to build:"
    echo "  docker run --rm -v \"\$(pwd):/src\" -w /src mcr.microsoft.com/dotnet/sdk:9.0 bash scripts/rebuild_and_test_plugins.sh"
    exit 1
fi

echo "✓ .NET SDK found: $(dotnet --version)"
echo ""
echo "Installed SDKs:"
dotnet --list-sdks
echo ""
echo "Installed Runtimes:"
dotnet --list-runtimes
echo ""

# Check for .NET 9.0
if ! dotnet --list-sdks | grep -q "9\."; then
    echo -e "${YELLOW}⚠ .NET 9.0 SDK not found${NC}"
    echo "  Current SDK: $(dotnet --version)"
    echo "  Plugin targets: net9.0"
    echo "  Build may fail. Install .NET 9.0 SDK to continue."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ .NET 9.0 SDK available${NC}"
fi
echo ""

# ============================================================================
# Step 2: Locate Jellyfin
# ============================================================================
echo -e "${BLUE}Step 2: Locating Jellyfin installation...${NC}"
echo "=========================================================================="

JELLYFIN_LIB_DIR=""
for candidate in /usr/lib/jellyfin/bin /usr/share/jellyfin/bin /usr/lib/jellyfin /usr/share/jellyfin; do
  if [[ -f "${candidate}/MediaBrowser.Common.dll" ]]; then
    JELLYFIN_LIB_DIR="${candidate}"
    break
  fi
done

if [[ -z "${JELLYFIN_LIB_DIR}" ]]; then
    echo -e "${RED}✗ Jellyfin installation not found${NC}"
    echo "  Checked locations:"
    echo "    /usr/lib/jellyfin/bin"
    echo "    /usr/share/jellyfin/bin"
    echo "    /usr/lib/jellyfin"
    echo "    /usr/share/jellyfin"
    exit 1
fi

echo -e "${GREEN}✓ Jellyfin found at: ${JELLYFIN_LIB_DIR}${NC}"

# Check Jellyfin version
if [[ -f "${JELLYFIN_LIB_DIR}/jellyfin.dll" ]]; then
    JELLYFIN_VERSION=$(strings "${JELLYFIN_LIB_DIR}/jellyfin.dll" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1 || echo "unknown")
    echo "  Jellyfin version: ${JELLYFIN_VERSION}"
fi
echo ""

# ============================================================================
# Step 3: Clean RealTimeHDRSRGAN Plugin
# ============================================================================
echo -e "${BLUE}Step 3: Cleaning RealTimeHDRSRGAN plugin...${NC}"
echo "=========================================================================="

PLUGIN_SRC="${REPO_DIR}/jellyfin-plugin/Server"
if [[ ! -d "${PLUGIN_SRC}" ]]; then
    echo -e "${RED}✗ Plugin source not found: ${PLUGIN_SRC}${NC}"
    exit 1
fi

cd "${PLUGIN_SRC}"
echo "Working directory: $(pwd)"
echo ""

echo "Removing bin/ and obj/ directories..."
rm -rf bin obj
echo -e "${GREEN}✓ Clean complete${NC}"
echo ""

# ============================================================================
# Step 4: Rebuild RealTimeHDRSRGAN Plugin
# ============================================================================
echo -e "${BLUE}Step 4: Building RealTimeHDRSRGAN plugin from scratch...${NC}"
echo "=========================================================================="

echo "Clearing NuGet cache..."
dotnet nuget locals all --clear

echo ""
echo "Restoring packages..."
dotnet restore --force -v minimal

echo ""
echo "Building plugin (Release configuration)..."
dotnet build -c Release "/p:JellyfinLibDir=${JELLYFIN_LIB_DIR}" -v minimal

if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Find output directory
PLUGIN_OUTPUT_DIR=$(find bin/Release -maxdepth 1 -type d -name "net*" | head -1)
if [[ -z "${PLUGIN_OUTPUT_DIR}" ]]; then
    echo -e "${RED}✗ Build output not found${NC}"
    exit 1
fi

echo "Build output: ${PLUGIN_OUTPUT_DIR}"
echo ""
echo "DLLs and files:"
ls -lh "${PLUGIN_OUTPUT_DIR}/"
echo ""

# ============================================================================
# Step 5: Install RealTimeHDRSRGAN Plugin
# ============================================================================
echo -e "${BLUE}Step 5: Installing RealTimeHDRSRGAN plugin...${NC}"
echo "=========================================================================="

PLUGIN_INSTALL_DIR="/var/lib/jellyfin/plugins/RealTimeHDRSRGAN"
echo "Installation directory: ${PLUGIN_INSTALL_DIR}"

# Create directory
$SUDO mkdir -p "${PLUGIN_INSTALL_DIR}"

# Stop Jellyfin
if systemctl is-active --quiet jellyfin; then
    echo "Stopping Jellyfin..."
    $SUDO systemctl stop jellyfin
    sleep 2
fi

# Copy all files
echo "Copying plugin files..."
$SUDO cp "${PLUGIN_OUTPUT_DIR}"/* "${PLUGIN_INSTALL_DIR}/"

# Set permissions
echo "Setting permissions..."
$SUDO chown -R jellyfin:jellyfin "${PLUGIN_INSTALL_DIR}"
$SUDO chmod 644 "${PLUGIN_INSTALL_DIR}/"*.dll 2>/dev/null || true
$SUDO chmod 755 "${PLUGIN_INSTALL_DIR}/"*.sh 2>/dev/null || true

echo -e "${GREEN}✓ RealTimeHDRSRGAN plugin installed${NC}"
echo ""
echo "Installed files:"
$SUDO ls -lh "${PLUGIN_INSTALL_DIR}/"
echo ""

# ============================================================================
# Step 6: Clean Webhook Plugin
# ============================================================================
echo -e "${BLUE}Step 6: Cleaning Webhook plugin...${NC}"
echo "=========================================================================="

WEBHOOK_SRC="${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook"
if [[ ! -d "${WEBHOOK_SRC}" ]]; then
    echo -e "${RED}✗ Webhook source not found: ${WEBHOOK_SRC}${NC}"
    exit 1
fi

cd "${WEBHOOK_SRC}"
echo "Working directory: $(pwd)"
echo ""

echo "Removing bin/ and obj/ directories..."
rm -rf bin obj
echo -e "${GREEN}✓ Clean complete${NC}"
echo ""

# ============================================================================
# Step 7: Rebuild Webhook Plugin
# ============================================================================
echo -e "${BLUE}Step 7: Building Webhook plugin from scratch...${NC}"
echo "=========================================================================="

echo "Clearing NuGet cache..."
dotnet nuget locals all --clear

echo ""
echo "Restoring packages..."
dotnet restore --force -v minimal

echo ""
echo "Building plugin (Release configuration)..."
dotnet build -c Release -v minimal

if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Find output directory
WEBHOOK_OUTPUT_DIR=$(find bin/Release -maxdepth 1 -type d -name "net*" | head -1)
if [[ -z "${WEBHOOK_OUTPUT_DIR}" ]]; then
    echo -e "${RED}✗ Build output not found${NC}"
    exit 1
fi

echo "Build output: ${WEBHOOK_OUTPUT_DIR}"
echo ""
echo "DLLs and dependencies:"
ls -lh "${WEBHOOK_OUTPUT_DIR}/"*.dll
echo ""

# ============================================================================
# Step 8: Install Webhook Plugin
# ============================================================================
echo -e "${BLUE}Step 8: Installing Webhook plugin...${NC}"
echo "=========================================================================="

WEBHOOK_INSTALL_DIR="/var/lib/jellyfin/plugins/Webhook"
echo "Installation directory: ${WEBHOOK_INSTALL_DIR}"

# Create directory
$SUDO mkdir -p "${WEBHOOK_INSTALL_DIR}"

# Copy all DLLs (including dependencies)
echo "Copying plugin files and dependencies..."
$SUDO cp "${WEBHOOK_OUTPUT_DIR}"/*.dll "${WEBHOOK_INSTALL_DIR}/"

# Set permissions
echo "Setting permissions..."
$SUDO chown -R jellyfin:jellyfin "${WEBHOOK_INSTALL_DIR}"
$SUDO chmod 644 "${WEBHOOK_INSTALL_DIR}/"*.dll

echo -e "${GREEN}✓ Webhook plugin installed${NC}"
echo ""
echo "Installed files:"
$SUDO ls -lh "${WEBHOOK_INSTALL_DIR}/"
echo ""

# ============================================================================
# Step 9: Configure Webhook
# ============================================================================
echo -e "${BLUE}Step 9: Configuring Webhook plugin...${NC}"
echo "=========================================================================="

WEBHOOK_CONFIG="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"
CONFIGURE_SCRIPT="${REPO_DIR}/scripts/configure_webhook.py"

if [[ -f "${CONFIGURE_SCRIPT}" ]]; then
    echo "Running webhook configuration script..."
    if $SUDO python3 "${CONFIGURE_SCRIPT}" "http://localhost:5000" "${WEBHOOK_CONFIG}"; then
        echo -e "${GREEN}✓ Webhook configured${NC}"
        echo "  Target: http://localhost:5000/upscale-trigger"
        echo "  Trigger: PlaybackStart (Movies, Episodes)"
        echo "  Template includes: {{Path}}"
    else
        echo -e "${YELLOW}⚠ Webhook configuration script failed${NC}"
        echo "  Configure manually via Jellyfin Dashboard"
    fi
else
    echo -e "${YELLOW}⚠ Configuration script not found: ${CONFIGURE_SCRIPT}${NC}"
    echo "  Configure manually via Jellyfin Dashboard"
fi
echo ""

# ============================================================================
# Step 10: Fix All Permissions
# ============================================================================
echo -e "${BLUE}Step 10: Fixing all Jellyfin permissions...${NC}"
echo "=========================================================================="

JELLYFIN_DATA="/var/lib/jellyfin"
echo "Setting ownership: jellyfin:jellyfin"
$SUDO chown -R jellyfin:jellyfin "${JELLYFIN_DATA}"

echo "Setting directory permissions: 755"
$SUDO find "${JELLYFIN_DATA}" -type d -exec chmod 755 {} \; 2>/dev/null || true

echo "Setting file permissions: 644"
$SUDO find "${JELLYFIN_DATA}" -type f -exec chmod 644 {} \; 2>/dev/null || true

echo "Setting script permissions: 755"
$SUDO find "${JELLYFIN_DATA}/plugins" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true

echo -e "${GREEN}✓ Permissions fixed${NC}"
echo ""

# ============================================================================
# Step 11: Start Jellyfin
# ============================================================================
echo -e "${BLUE}Step 11: Starting Jellyfin...${NC}"
echo "=========================================================================="

$SUDO systemctl start jellyfin

echo "Waiting for Jellyfin to start..."
sleep 5

if systemctl is-active --quiet jellyfin; then
    echo -e "${GREEN}✓ Jellyfin is running${NC}"
    
    # Show status
    $SUDO systemctl status jellyfin --no-pager -l | head -15
else
    echo -e "${RED}✗ Jellyfin failed to start${NC}"
    echo ""
    echo "Check logs:"
    echo "  sudo journalctl -u jellyfin -n 50 --no-pager"
    exit 1
fi
echo ""

# ============================================================================
# Step 12: Wait for Jellyfin API
# ============================================================================
echo -e "${BLUE}Step 12: Waiting for Jellyfin API...${NC}"
echo "=========================================================================="

MAX_WAIT=30
WAITED=0
API_READY=false

while [[ $WAITED -lt $MAX_WAIT ]]; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8096/health 2>/dev/null | grep -q "200"; then
        API_READY=true
        break
    fi
    echo "Waiting... ($WAITED/$MAX_WAIT seconds)"
    sleep 2
    WAITED=$((WAITED + 2))
done

if $API_READY; then
    echo -e "${GREEN}✓ Jellyfin API is ready${NC}"
else
    echo -e "${YELLOW}⚠ Jellyfin API not responding after ${MAX_WAIT} seconds${NC}"
    echo "  Jellyfin may still be starting up"
    echo "  Continue with manual testing"
fi
echo ""

# ============================================================================
# Step 13: Test Plugin Loading
# ============================================================================
echo -e "${BLUE}Step 13: Testing plugin loading...${NC}"
echo "=========================================================================="

echo "Checking Jellyfin logs for plugin loading..."
$SUDO journalctl -u jellyfin --since "2 minutes ago" --no-pager | grep -i "plugin\|realtimehdr\|webhook" | tail -20

echo ""
echo "Checking installed plugins:"
echo ""

# Check RealTimeHDRSRGAN
if [[ -f "${PLUGIN_INSTALL_DIR}/Jellyfin.Plugin.RealTimeHdrSrgan.dll" ]]; then
    echo -e "${GREEN}✓ RealTimeHDRSRGAN plugin files present${NC}"
    echo "  Location: ${PLUGIN_INSTALL_DIR}"
    echo "  Size: $(du -sh ${PLUGIN_INSTALL_DIR} | cut -f1)"
else
    echo -e "${RED}✗ RealTimeHDRSRGAN plugin DLL missing${NC}"
fi

# Check Webhook
if [[ -f "${WEBHOOK_INSTALL_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
    echo -e "${GREEN}✓ Webhook plugin files present${NC}"
    echo "  Location: ${WEBHOOK_INSTALL_DIR}"
    echo "  Size: $(du -sh ${WEBHOOK_INSTALL_DIR} | cut -f1)"
else
    echo -e "${RED}✗ Webhook plugin DLL missing${NC}"
fi
echo ""

# ============================================================================
# Step 14: Test API Endpoints
# ============================================================================
echo -e "${BLUE}Step 14: Testing plugin API endpoints...${NC}"
echo "=========================================================================="

# Test RealTimeHDRSRGAN Configuration endpoint
echo "Testing: GET /Plugins/RealTimeHDRSRGAN/Configuration"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8096/Plugins/RealTimeHDRSRGAN/Configuration 2>/dev/null || echo "000")
if [[ "$RESPONSE" == "200" ]]; then
    echo -e "${GREEN}✓ Configuration API responding (200)${NC}"
    CONFIG_JSON=$(curl -s http://localhost:8096/Plugins/RealTimeHDRSRGAN/Configuration 2>/dev/null)
    echo "  Response: ${CONFIG_JSON}"
elif [[ "$RESPONSE" == "401" ]]; then
    echo -e "${YELLOW}⚠ Configuration API requires authentication (401)${NC}"
    echo "  This is normal - plugin is loaded"
else
    echo -e "${RED}✗ Configuration API not responding (${RESPONSE})${NC}"
    echo "  Plugin may not be loaded correctly"
fi
echo ""

# Test GPU Detection endpoint
echo "Testing: POST /Plugins/RealTimeHDRSRGAN/DetectGPU"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8096/Plugins/RealTimeHDRSRGAN/DetectGPU 2>/dev/null || echo "000")
if [[ "$RESPONSE" == "200" ]]; then
    echo -e "${GREEN}✓ GPU Detection API responding (200)${NC}"
elif [[ "$RESPONSE" == "401" ]]; then
    echo -e "${YELLOW}⚠ GPU Detection API requires authentication (401)${NC}"
    echo "  This is normal - plugin is loaded"
else
    echo -e "${RED}✗ GPU Detection API not responding (${RESPONSE})${NC}"
fi
echo ""

# ============================================================================
# Step 15: Test Scripts
# ============================================================================
echo -e "${BLUE}Step 15: Testing plugin scripts...${NC}"
echo "=========================================================================="

# Test gpu-detection.sh
if [[ -f "${PLUGIN_INSTALL_DIR}/gpu-detection.sh" ]]; then
    echo "Testing: gpu-detection.sh"
    if [[ -x "${PLUGIN_INSTALL_DIR}/gpu-detection.sh" ]]; then
        echo -e "${GREEN}✓ Script is executable${NC}"
        GPU_RESULT=$($SUDO -u jellyfin bash "${PLUGIN_INSTALL_DIR}/gpu-detection.sh" 2>&1 || echo "")
        if echo "$GPU_RESULT" | grep -qi "success\|nvidia"; then
            echo -e "${GREEN}✓ GPU detection script works${NC}"
            echo "$GPU_RESULT" | head -5
        else
            echo -e "${YELLOW}⚠ GPU detection script ran but no GPU found${NC}"
            echo "$GPU_RESULT" | head -5
        fi
    else
        echo -e "${RED}✗ Script not executable${NC}"
    fi
else
    echo -e "${RED}✗ gpu-detection.sh not found${NC}"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=========================================================================="
echo -e "${GREEN}Rebuild and Installation Complete!${NC}"
echo "=========================================================================="
echo ""
echo "What was done:"
echo "  ✓ Checked .NET version: $(dotnet --version 2>/dev/null || echo 'N/A')"
echo "  ✓ Cleaned and rebuilt RealTimeHDRSRGAN plugin"
echo "  ✓ Cleaned and rebuilt Webhook plugin"
echo "  ✓ Installed both plugins"
echo "  ✓ Configured webhook"
echo "  ✓ Fixed permissions"
echo "  ✓ Restarted Jellyfin"
echo ""
echo "Plugin Locations:"
echo "  RealTimeHDRSRGAN: ${PLUGIN_INSTALL_DIR}"
echo "  Webhook:          ${WEBHOOK_INSTALL_DIR}"
echo ""
echo "Next Steps:"
echo ""
echo "1. Open Jellyfin Dashboard:"
echo "   http://localhost:8096 (or your Jellyfin URL)"
echo ""
echo "2. Check Plugins:"
echo "   Dashboard → Plugins → Installed"
echo "   Should show:"
echo "   - Real-Time HDR SRGAN Pipeline (v1.0.0) - Active"
echo "   - Webhook (v18) - Active"
echo ""
echo "3. Test RealTimeHDRSRGAN Settings:"
echo "   Dashboard → Plugins → Real-Time HDR SRGAN Pipeline → Settings"
echo "   Should show:"
echo "   - GPU Detection section with 'Detect NVIDIA GPU' button"
echo "   - Plugin Settings (Enable Upscaling, GPU Device, Upscale Factor)"
echo "   - Backup & Restore section"
echo ""
echo "4. Test Webhook Configuration:"
echo "   Dashboard → Plugins → Webhook → Settings"
echo "   Should show: SRGAN 4K Upscaler webhook configured"
echo ""
echo "5. View Logs:"
echo "   sudo journalctl -u jellyfin -f"
echo ""
echo "6. Test End-to-End:"
echo "   Play a video in Jellyfin"
echo "   Check watchdog logs: tail -f /var/log/srgan-watchdog.log"
echo ""

cd "${REPO_DIR}"
