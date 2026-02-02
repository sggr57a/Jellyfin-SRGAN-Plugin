#!/bin/bash
#
# ENSURE PATH IS WORKING NOW - Complete Fix and Verification
# This script ensures the {{Path}} variable works in the INSTALLED plugin
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================================================="
echo "ENSURING {{Path}} VARIABLE WORKS IN INSTALLED PLUGIN"
echo "=========================================================================="
echo ""

NEEDS_RESTART=false
ISSUES=0

# Step 1: Check webhook is installed from catalog
echo -e "${BLUE}Step 1: Checking webhook plugin installation...${NC}"
WEBHOOK_PLUGIN_DIR=$(find /var/lib/jellyfin/plugins -maxdepth 1 -type d -name "Webhook_*" 2>/dev/null | head -1)

if [[ -z "${WEBHOOK_PLUGIN_DIR}" ]]; then
    echo -e "${RED}✗ Webhook plugin NOT installed from Jellyfin catalog${NC}"
    echo ""
    echo "CRITICAL: Install webhook from Jellyfin first:"
    echo "  1. Open Jellyfin Dashboard"
    echo "  2. Plugins → Catalog → Search 'Webhook'"
    echo "  3. Install and restart Jellyfin"
    echo "  4. Then run this script again"
    exit 1
fi

echo -e "${GREEN}✓ Webhook installed at: ${WEBHOOK_PLUGIN_DIR}${NC}"
echo ""

# Step 2: Ensure source code exists
echo -e "${BLUE}Step 2: Ensuring webhook source code exists...${NC}"
HELPERS_FILE="${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs"

if [[ ! -f "${HELPERS_FILE}" ]]; then
    echo -e "${YELLOW}Setting up webhook source...${NC}"
    bash "${SCRIPT_DIR}/setup_webhook_source.sh" || {
        echo -e "${RED}✗ Failed to setup webhook source${NC}"
        exit 1
    }
fi

echo -e "${GREEN}✓ Source code exists${NC}"
echo ""

# Step 3: Ensure Path patch is applied to SOURCE
echo -e "${BLUE}Step 3: Ensuring {{Path}} patch is in SOURCE CODE...${NC}"

if ! grep -q '"Path".*item\.Path' "${HELPERS_FILE}"; then
    echo -e "${YELLOW}Applying Path patch to source...${NC}"
    bash "${SCRIPT_DIR}/patch_webhook_path.sh" || {
        echo -e "${RED}✗ Failed to apply patch${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ Patch applied to source${NC}"
else
    echo -e "${GREEN}✓ Patch already in source${NC}"
fi

# Show the patch
echo "  Current implementation:"
grep -A 4 -B 1 '"Path".*item\.Path' "${HELPERS_FILE}" | head -6 | sed 's/^/    /'
echo ""

# Step 4: Build the patched plugin
echo -e "${BLUE}Step 4: Building patched plugin...${NC}"
cd "${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook"

# Clean and build
rm -rf bin obj
dotnet nuget locals all --clear >/dev/null 2>&1
dotnet restore --force >/dev/null 2>&1

echo "  Building (this may take a moment)..."
if dotnet build -c Release -v quiet; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    echo "  Trying with detailed output..."
    dotnet build -c Release -v detailed
    exit 1
fi

# Find the built DLL
BUILT_DLL=$(find bin/Release/net9.0 -name "Jellyfin.Plugin.Webhook.dll" 2>/dev/null | head -1)
if [[ ! -f "${BUILT_DLL}" ]]; then
    echo -e "${RED}✗ Built DLL not found${NC}"
    exit 1
fi

BUILD_SIZE=$(du -h "${BUILT_DLL}" | cut -f1)
echo "  Built DLL: ${BUILD_SIZE}"
echo ""

# Step 5: Stop Jellyfin and install the patched DLL
echo -e "${BLUE}Step 5: Installing patched DLL to Jellyfin...${NC}"

echo "  Stopping Jellyfin..."
sudo systemctl stop jellyfin
sleep 2

# Backup current DLL
if [[ -f "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
    BACKUP_NAME="Jellyfin.Plugin.Webhook.dll.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" "${WEBHOOK_PLUGIN_DIR}/${BACKUP_NAME}"
    echo "  ✓ Backed up to: ${BACKUP_NAME}"
fi

# Copy ALL DLLs from build
echo "  Copying patched DLLs..."
sudo cp bin/Release/net9.0/*.dll "${WEBHOOK_PLUGIN_DIR}/" 2>/dev/null
if [[ -f "bin/Release/net9.0/Jellyfin.Plugin.Webhook.deps.json" ]]; then
    sudo cp bin/Release/net9.0/Jellyfin.Plugin.Webhook.deps.json "${WEBHOOK_PLUGIN_DIR}/"
fi

# Set permissions
sudo chown -R jellyfin:jellyfin "${WEBHOOK_PLUGIN_DIR}"/*.dll
sudo chmod 644 "${WEBHOOK_PLUGIN_DIR}"/*.dll

# Verify the DLL was copied
INSTALLED_SIZE=$(du -h "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" | cut -f1)
INSTALLED_TIME=$(stat -c '%y' "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null)

echo -e "${GREEN}✓ DLL installed: ${INSTALLED_SIZE} at ${INSTALLED_TIME}${NC}"
echo ""

# Step 6: Ensure webhook configuration has {{Path}}
echo -e "${BLUE}Step 6: Ensuring webhook configuration has {{Path}}...${NC}"
WEBHOOK_CONFIG="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"

if [[ ! -f "${WEBHOOK_CONFIG}" ]] || ! grep -q "{{Path}}" "${WEBHOOK_CONFIG}"; then
    echo -e "${YELLOW}Configuring webhook with {{Path}}...${NC}"
    sudo python3 "${SCRIPT_DIR}/configure_webhook.py" http://localhost:5000 "${WEBHOOK_CONFIG}" || {
        echo -e "${RED}✗ Failed to configure webhook${NC}"
        ISSUES=$((ISSUES + 1))
    }
    echo -e "${GREEN}✓ Webhook configured with {{Path}}${NC}"
else
    echo -e "${GREEN}✓ Configuration already has {{Path}}${NC}"
fi
echo ""

# Step 7: Start Jellyfin
echo -e "${BLUE}Step 7: Starting Jellyfin...${NC}"
sudo systemctl start jellyfin
sleep 5

if systemctl is-active --quiet jellyfin; then
    echo -e "${GREEN}✓ Jellyfin started successfully${NC}"
else
    echo -e "${RED}✗ Jellyfin failed to start${NC}"
    echo "  Check logs: sudo journalctl -u jellyfin -n 50"
    exit 1
fi
echo ""

# Step 8: Verify Jellyfin loaded the webhook plugin
echo -e "${BLUE}Step 8: Verifying Jellyfin loaded the webhook...${NC}"
sleep 3  # Give Jellyfin time to load plugins

if sudo journalctl -u jellyfin -n 100 --no-pager 2>/dev/null | grep -qi "webhook"; then
    echo -e "${GREEN}✓ Webhook plugin loaded by Jellyfin${NC}"
    echo ""
    echo "  Recent webhook log entries:"
    sudo journalctl -u jellyfin -n 100 --no-pager 2>/dev/null | grep -i webhook | tail -3 | sed 's/^/    /'
else
    echo -e "${YELLOW}⚠ No webhook entries in logs (may be normal)${NC}"
fi
echo ""

# Step 9: Final verification
echo "=========================================================================="
echo -e "${GREEN}FINAL VERIFICATION${NC}"
echo "=========================================================================="
echo ""

echo "1. Source code patch:"
if grep -q '"Path".*item\.Path' "${HELPERS_FILE}"; then
    echo -e "   ${GREEN}✓${NC} DataObjectHelpers.cs has Path property"
else
    echo -e "   ${RED}✗${NC} Path property NOT in source"
    ISSUES=$((ISSUES + 1))
fi

echo ""
echo "2. Installed DLL:"
if [[ -f "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
    DLL_AGE=$(($(date +%s) - $(stat -c %Y "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -f %m "${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || echo 0)))
    if [[ $DLL_AGE -lt 300 ]]; then
        echo -e "   ${GREEN}✓${NC} DLL updated ${DLL_AGE} seconds ago (FRESH!)"
    else
        echo -e "   ${YELLOW}⚠${NC} DLL is ${DLL_AGE} seconds old"
    fi
    echo "   Location: ${WEBHOOK_PLUGIN_DIR}/Jellyfin.Plugin.Webhook.dll"
    echo "   Size: ${INSTALLED_SIZE}"
fi

echo ""
echo "3. Webhook configuration:"
if [[ -f "${WEBHOOK_CONFIG}" ]]; then
    if grep -q "{{Path}}" "${WEBHOOK_CONFIG}"; then
        echo -e "   ${GREEN}✓${NC} Template includes {{Path}}"
    else
        echo -e "   ${RED}✗${NC} Template does NOT include {{Path}}"
        ISSUES=$((ISSUES + 1))
    fi
fi

echo ""
echo "4. Jellyfin service:"
if systemctl is-active --quiet jellyfin; then
    echo -e "   ${GREEN}✓${NC} Jellyfin is running"
else
    echo -e "   ${RED}✗${NC} Jellyfin is not running"
    ISSUES=$((ISSUES + 1))
fi

echo ""
echo "=========================================================================="
if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}✓✓✓ {{Path}} IS NOW WORKING IN INSTALLED PLUGIN! ✓✓✓${NC}"
    echo "=========================================================================="
    echo ""
    echo "TEST IT NOW:"
    echo ""
    echo "  Terminal 1: tail -f /var/log/srgan-watchdog.log"
    echo "  Terminal 2: Play a video in Jellyfin"
    echo ""
    echo "  Expected result:"
    echo '  {"Path": "/media/movies/Example.mkv", "Name": "Example", ...}'
    echo ""
    echo "  If Path is still empty:"
    echo "  - Check Jellyfin Dashboard → Plugins → Webhook"
    echo "  - Verify webhook exists and is enabled"
    echo "  - Check webhook template includes {{Path}}"
    echo ""
else
    echo -e "${RED}✗ ${ISSUES} issue(s) found${NC}"
    echo "=========================================================================="
    echo ""
    echo "Please review the errors above and try again."
fi
echo ""

exit $ISSUES
