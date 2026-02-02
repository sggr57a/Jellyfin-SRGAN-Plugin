#!/bin/bash
#
# Complete Fix for {{Path}} Variable - Diagnostic and Repair
# This script verifies and fixes every step required for {{Path}} to work
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================================================="
echo "Complete {{Path}} Variable Fix - Diagnostic and Repair"
echo "=========================================================================="
echo ""

PROBLEMS_FOUND=0

# Step 1: Check webhook plugin is installed from catalog
echo -e "${BLUE}Step 1: Checking webhook plugin installation...${NC}"
WEBHOOK_DIR=$(find /var/lib/jellyfin/plugins -maxdepth 1 -type d -name "Webhook_*" 2>/dev/null | head -1)

if [[ -z "${WEBHOOK_DIR}" ]]; then
    echo -e "${RED}✗ Webhook plugin NOT installed from Jellyfin catalog${NC}"
    echo "  You MUST install it first:"
    echo "  1. Open Jellyfin Dashboard"
    echo "  2. Go to Plugins → Catalog"
    echo "  3. Search for 'Webhook'"
    echo "  4. Click Install"
    echo "  5. Restart Jellyfin"
    echo "  6. Then run this script again"
    exit 1
else
    echo -e "${GREEN}✓ Webhook plugin installed at: ${WEBHOOK_DIR}${NC}"
fi
echo ""

# Step 2: Check webhook source exists
echo -e "${BLUE}Step 2: Checking webhook source code...${NC}"
HELPERS_FILE="${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs"

if [[ ! -f "${HELPERS_FILE}" ]]; then
    echo -e "${YELLOW}⚠ Webhook source not found. Setting up...${NC}"
    if bash "${SCRIPT_DIR}/setup_webhook_source.sh"; then
        echo -e "${GREEN}✓ Webhook source setup complete${NC}"
    else
        echo -e "${RED}✗ Failed to setup webhook source${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Webhook source exists${NC}"
fi
echo ""

# Step 3: Check and apply Path patch
echo -e "${BLUE}Step 3: Checking {{Path}} patch...${NC}"

if ! grep -q '"Path".*item\.Path' "${HELPERS_FILE}"; then
    echo -e "${YELLOW}⚠ Path patch NOT applied. Applying now...${NC}"
    
    # Manually patch with better logic
    cp "${HELPERS_FILE}" "${HELPERS_FILE}.backup"
    
    # Find where to insert - look for AddBaseItemData method
    if grep -q "AddBaseItemData" "${HELPERS_FILE}"; then
        # Create the patch code
        PATCH_CODE='
        if (!string.IsNullOrEmpty(item.Path))
        {
            dataObject["Path"] = item.Path;
        }'
        
        # Find line with "ItemId" to insert after
        LINE_NUM=$(grep -n 'dataObject\["ItemId"\]' "${HELPERS_FILE}" | tail -1 | cut -d: -f1)
        
        if [[ -n "${LINE_NUM}" ]]; then
            {
                head -n "$LINE_NUM" "${HELPERS_FILE}"
                echo "$PATCH_CODE"
                tail -n +$((LINE_NUM + 1)) "${HELPERS_FILE}"
            } > "${HELPERS_FILE}.new"
            mv "${HELPERS_FILE}.new" "${HELPERS_FILE}"
            echo -e "${GREEN}✓ Path patch applied${NC}"
        else
            echo -e "${RED}✗ Could not find insertion point${NC}"
            PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
        fi
    else
        echo -e "${RED}✗ AddBaseItemData method not found${NC}"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
    fi
else
    echo -e "${GREEN}✓ Path patch already applied${NC}"
    echo "  Current implementation:"
    grep -A 3 -B 1 '"Path".*item\.Path' "${HELPERS_FILE}" | head -5
fi
echo ""

# Step 4: Build webhook plugin
echo -e "${BLUE}Step 4: Building webhook plugin...${NC}"
cd "${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook"

# Clean build
rm -rf bin obj
dotnet nuget locals all --clear >/dev/null 2>&1 || true

echo "  Building..."
if dotnet build -c Release -v quiet; then
    echo -e "${GREEN}✓ Build successful${NC}"
    
    # Find DLL
    BUILT_DLL=$(find bin/Release -name "Jellyfin.Plugin.Webhook.dll" | head -1)
    if [[ -f "${BUILT_DLL}" ]]; then
        DLL_SIZE=$(du -h "${BUILT_DLL}" | cut -f1)
        echo "  DLL: ${BUILT_DLL} (${DLL_SIZE})"
    else
        echo -e "${RED}✗ DLL not found after build${NC}"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
    fi
else
    echo -e "${RED}✗ Build failed${NC}"
    echo "  Trying with detailed output..."
    dotnet build -c Release -v detailed
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi
echo ""

# Step 5: Install DLL to Jellyfin
if [[ -f "${BUILT_DLL}" ]] && [[ -n "${WEBHOOK_DIR}" ]]; then
    echo -e "${BLUE}Step 5: Installing webhook DLL to Jellyfin...${NC}"
    
    # Stop Jellyfin
    echo "  Stopping Jellyfin..."
    sudo systemctl stop jellyfin
    sleep 2
    
    # Backup existing
    if [[ -f "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
        sudo cp "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll" "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll.backup"
        echo "  ✓ Backed up existing DLL"
    fi
    
    # Copy new DLL and all dependencies
    echo "  Copying new DLL..."
    sudo cp "${BUILT_DLL}" "${WEBHOOK_DIR}/"
    sudo cp "bin/Release/net9.0/"*.dll "${WEBHOOK_DIR}/" 2>/dev/null || true
    
    # Set permissions
    sudo chown jellyfin:jellyfin "${WEBHOOK_DIR}"/*.dll
    sudo chmod 644 "${WEBHOOK_DIR}"/*.dll
    
    echo -e "${GREEN}✓ DLL installed${NC}"
    ls -lh "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll"
    
    # Start Jellyfin
    echo "  Starting Jellyfin..."
    sudo systemctl start jellyfin
    sleep 5
    
    if systemctl is-active --quiet jellyfin; then
        echo -e "${GREEN}✓ Jellyfin started${NC}"
    else
        echo -e "${RED}✗ Jellyfin failed to start${NC}"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
    fi
else
    echo -e "${YELLOW}⚠ Skipping DLL installation (build failed or plugin not installed)${NC}"
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi
echo ""

# Step 6: Verify webhook configuration
echo -e "${BLUE}Step 6: Checking webhook configuration...${NC}"
WEBHOOK_CONFIG="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"

if [[ -f "${WEBHOOK_CONFIG}" ]]; then
    # Check if {{Path}} is in the template
    if grep -q "{{Path}}" "${WEBHOOK_CONFIG}"; then
        echo -e "${GREEN}✓ Webhook configuration includes {{Path}}${NC}"
    else
        echo -e "${YELLOW}⚠ {{Path}} not in webhook configuration. Reconfiguring...${NC}"
        
        if sudo python3 "${SCRIPT_DIR}/configure_webhook.py" http://localhost:5000 "${WEBHOOK_CONFIG}"; then
            echo -e "${GREEN}✓ Webhook reconfigured with {{Path}}${NC}"
            sudo systemctl restart jellyfin
            sleep 5
        else
            echo -e "${RED}✗ Failed to reconfigure webhook${NC}"
            PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
        fi
    fi
    
    # Show template
    echo "  Webhook template:"
    grep -A 2 "<Template>" "${WEBHOOK_CONFIG}" | base64 -d 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "  (Could not decode template)"
else
    echo -e "${YELLOW}⚠ Webhook configuration not found${NC}"
    echo "  Creating configuration..."
    if sudo python3 "${SCRIPT_DIR}/configure_webhook.py" http://localhost:5000 "${WEBHOOK_CONFIG}"; then
        echo -e "${GREEN}✓ Webhook configured${NC}"
        sudo systemctl restart jellyfin
        sleep 5
    else
        echo -e "${RED}✗ Failed to configure webhook${NC}"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
    fi
fi
echo ""

# Step 7: Final verification
echo -e "${BLUE}Step 7: Final verification...${NC}"
echo ""

echo "Checking Jellyfin logs for plugin loading..."
sudo journalctl -u jellyfin -n 100 --no-pager | grep -i webhook | tail -5 || echo "No webhook messages in logs"
echo ""

echo "Verifying patch in source code..."
if grep -q '"Path".*item\.Path' "${HELPERS_FILE}"; then
    echo -e "${GREEN}✓ Path patch present in source${NC}"
    grep -A 3 -B 1 '"Path".*item\.Path' "${HELPERS_FILE}" | head -5
else
    echo -e "${RED}✗ Path patch NOT in source${NC}"
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi
echo ""

echo "Verifying DLL timestamp..."
if [[ -f "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
    DLL_DATE=$(stat -c '%y' "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -f '%Sm' "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || echo "unknown")
    echo "  DLL modified: ${DLL_DATE}"
    
    # Check if modified in last 5 minutes
    if [[ -f "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll" ]]; then
        AGE=$(($(date +%s) - $(stat -c %Y "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -f %m "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || echo 0)))
        if [[ $AGE -lt 300 ]]; then
            echo -e "${GREEN}✓ DLL was recently updated (${AGE} seconds ago)${NC}"
        else
            echo -e "${YELLOW}⚠ DLL is old (${AGE} seconds ago)${NC}"
        fi
    fi
fi
echo ""

# Summary
echo "=========================================================================="
if [[ $PROBLEMS_FOUND -eq 0 ]]; then
    echo -e "${GREEN}✓ All Checks Passed!${NC}"
    echo "=========================================================================="
    echo ""
    echo "The {{Path}} variable should now work!"
    echo ""
    echo "Test it:"
    echo "  1. Open terminal: tail -f /var/log/srgan-watchdog.log"
    echo "  2. Play a video in Jellyfin"
    echo "  3. Check logs for: \"Path\": \"/media/movies/Example.mkv\""
    echo ""
    echo "If Path is still empty:"
    echo "  1. Check Jellyfin Dashboard → Plugins → Webhook"
    echo "  2. Verify webhook exists and is enabled"
    echo "  3. Check webhook template includes {{Path}}"
    echo "  4. Restart Jellyfin: sudo systemctl restart jellyfin"
else
    echo -e "${RED}✗ ${PROBLEMS_FOUND} Problem(s) Found${NC}"
    echo "=========================================================================="
    echo ""
    echo "Please fix the errors above and run this script again."
    echo ""
    echo "Common issues:"
    echo "  1. Webhook not installed from catalog - install from Jellyfin Dashboard"
    echo "  2. Build errors - check .NET SDK is installed"
    echo "  3. Permission errors - run with sudo"
    echo "  4. Jellyfin not running - check: sudo systemctl status jellyfin"
fi
echo ""

exit $PROBLEMS_FOUND
