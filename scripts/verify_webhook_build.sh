#!/bin/bash
#
# Verify Webhook Plugin Build - Check All Files Are Created and Copied
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
echo "Webhook Plugin Build Verification"
echo "=========================================================================="
echo ""

ISSUES=0

# 1. Check source files exist
echo -e "${BLUE}1. Checking webhook source files...${NC}"
WEBHOOK_SRC="${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook"

REQUIRED_SOURCE_FILES=(
    "Jellyfin.Plugin.Webhook.csproj"
    "NuGet.Config"
    "Helpers/DataObjectHelpers.cs"
    "Configuration/Web/config.html"
    "Configuration/Web/config.js"
)

for file in "${REQUIRED_SOURCE_FILES[@]}"; do
    if [[ -f "${WEBHOOK_SRC}/${file}" ]]; then
        echo -e "  ${GREEN}✓${NC} ${file}"
    else
        echo -e "  ${RED}✗${NC} ${file} - MISSING!"
        ISSUES=$((ISSUES + 1))
    fi
done
echo ""

# 2. Check Path patch is applied
echo -e "${BLUE}2. Checking {{Path}} patch...${NC}"
HELPERS_FILE="${WEBHOOK_SRC}/Helpers/DataObjectHelpers.cs"
if [[ -f "${HELPERS_FILE}" ]]; then
    if grep -q '"Path".*item\.Path' "${HELPERS_FILE}"; then
        echo -e "  ${GREEN}✓${NC} Path patch applied"
        echo "  Implementation:"
        grep -A 3 -B 1 '"Path".*item\.Path' "${HELPERS_FILE}" | sed 's/^/    /'
    else
        echo -e "  ${RED}✗${NC} Path patch NOT applied"
        echo "  Run: ./scripts/patch_webhook_path.sh"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo -e "  ${RED}✗${NC} DataObjectHelpers.cs not found"
    echo "  Run: ./scripts/setup_webhook_source.sh"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 3. Check build output
echo -e "${BLUE}3. Checking build output...${NC}"
BUILD_DIR="${WEBHOOK_SRC}/bin/Release/net9.0"

if [[ -d "${BUILD_DIR}" ]]; then
    echo -e "  ${GREEN}✓${NC} Build directory exists"
    
    REQUIRED_BUILD_FILES=(
        "Jellyfin.Plugin.Webhook.dll"
        "Jellyfin.Plugin.Webhook.deps.json"
        "Handlebars.Net.dll"
        "MailKit.dll"
    )
    
    for file in "${REQUIRED_BUILD_FILES[@]}"; do
        if [[ -f "${BUILD_DIR}/${file}" ]]; then
            SIZE=$(du -h "${BUILD_DIR}/${file}" | cut -f1)
            echo -e "  ${GREEN}✓${NC} ${file} (${SIZE})"
        else
            echo -e "  ${RED}✗${NC} ${file} - MISSING!"
            ISSUES=$((ISSUES + 1))
        fi
    done
    
    # Check embedded resources in DLL
    echo ""
    echo "  Checking embedded resources..."
    if command -v strings >/dev/null 2>&1; then
        if strings "${BUILD_DIR}/Jellyfin.Plugin.Webhook.dll" | grep -q "config.html"; then
            echo -e "  ${GREEN}✓${NC} config.html embedded in DLL"
        else
            echo -e "  ${YELLOW}⚠${NC} config.html may not be embedded"
        fi
        
        if strings "${BUILD_DIR}/Jellyfin.Plugin.Webhook.dll" | grep -q "config.js"; then
            echo -e "  ${GREEN}✓${NC} config.js embedded in DLL"
        else
            echo -e "  ${YELLOW}⚠${NC} config.js may not be embedded"
        fi
    else
        echo "  (strings command not available - skipping embedded resource check)"
    fi
else
    echo -e "  ${RED}✗${NC} Build directory not found"
    echo "  Run: cd ${WEBHOOK_SRC} && dotnet build -c Release"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 4. Check installation location
echo -e "${BLUE}4. Checking Jellyfin installation...${NC}"
WEBHOOK_INSTALL_DIR=$(find /var/lib/jellyfin/plugins -maxdepth 1 -type d -name "Webhook_*" 2>/dev/null | head -1)

if [[ -n "${WEBHOOK_INSTALL_DIR}" ]]; then
    echo -e "  ${GREEN}✓${NC} Webhook plugin directory: ${WEBHOOK_INSTALL_DIR}"
    
    REQUIRED_INSTALL_FILES=(
        "Jellyfin.Plugin.Webhook.dll"
        "Handlebars.Net.dll"
        "MailKit.dll"
        "MQTTnet.dll"
        "MQTTnet.Extensions.ManagedClient.dll"
    )
    
    for file in "${REQUIRED_INSTALL_FILES[@]}"; do
        if [[ -f "${WEBHOOK_INSTALL_DIR}/${file}" ]]; then
            SIZE=$(du -h "${WEBHOOK_INSTALL_DIR}/${file}" | cut -f1)
            MOD_TIME=$(stat -c '%y' "${WEBHOOK_INSTALL_DIR}/${file}" 2>/dev/null || stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "${WEBHOOK_INSTALL_DIR}/${file}" 2>/dev/null)
            echo -e "  ${GREEN}✓${NC} ${file} (${SIZE}) - ${MOD_TIME}"
        else
            echo -e "  ${RED}✗${NC} ${file} - NOT INSTALLED!"
            ISSUES=$((ISSUES + 1))
        fi
    done
    
    # Check file permissions
    echo ""
    echo "  Checking permissions..."
    OWNER=$(stat -c '%U:%G' "${WEBHOOK_INSTALL_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -f '%Su:%Sg' "${WEBHOOK_INSTALL_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null)
    PERMS=$(stat -c '%a' "${WEBHOOK_INSTALL_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -f '%Lp' "${WEBHOOK_INSTALL_DIR}/Jellyfin.Plugin.Webhook.dll" 2>/dev/null)
    
    if [[ "${OWNER}" == "jellyfin:jellyfin" ]]; then
        echo -e "  ${GREEN}✓${NC} Owner: ${OWNER}"
    else
        echo -e "  ${YELLOW}⚠${NC} Owner: ${OWNER} (expected jellyfin:jellyfin)"
    fi
    
    if [[ "${PERMS}" == "644" ]]; then
        echo -e "  ${GREEN}✓${NC} Permissions: ${PERMS}"
    else
        echo -e "  ${YELLOW}⚠${NC} Permissions: ${PERMS} (expected 644)"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Webhook plugin not installed in Jellyfin"
    echo "  Install from: Dashboard → Plugins → Catalog → Webhook"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 5. Check configuration
echo -e "${BLUE}5. Checking webhook configuration...${NC}"
WEBHOOK_CONFIG="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"

if [[ -f "${WEBHOOK_CONFIG}" ]]; then
    echo -e "  ${GREEN}✓${NC} Configuration file exists"
    
    if grep -q "{{Path}}" "${WEBHOOK_CONFIG}"; then
        echo -e "  ${GREEN}✓${NC} Template includes {{Path}}"
    else
        echo -e "  ${RED}✗${NC} Template does NOT include {{Path}}"
        echo "  Run: sudo python3 ${REPO_DIR}/scripts/configure_webhook.py http://localhost:5000"
        ISSUES=$((ISSUES + 1))
    fi
    
    if grep -q "SRGAN 4K Upscaler" "${WEBHOOK_CONFIG}"; then
        echo -e "  ${GREEN}✓${NC} SRGAN webhook configured"
    else
        echo -e "  ${YELLOW}⚠${NC} SRGAN webhook not found in config"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Configuration file not found"
    echo "  Will be created on first use or run configure_webhook.py"
fi
echo ""

# 6. Check Jellyfin recognizes the plugin
echo -e "${BLUE}6. Checking Jellyfin plugin status...${NC}"
if systemctl is-active --quiet jellyfin; then
    echo -e "  ${GREEN}✓${NC} Jellyfin service is running"
    
    # Check logs for plugin loading
    if sudo journalctl -u jellyfin -n 200 --no-pager 2>/dev/null | grep -q "Webhook"; then
        echo -e "  ${GREEN}✓${NC} Webhook plugin mentioned in logs"
        echo ""
        echo "  Recent webhook log entries:"
        sudo journalctl -u jellyfin -n 200 --no-pager 2>/dev/null | grep -i webhook | tail -3 | sed 's/^/    /'
    else
        echo -e "  ${YELLOW}⚠${NC} No webhook entries in recent logs"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Jellyfin service not running"
    echo "  Start: sudo systemctl start jellyfin"
fi
echo ""

# Summary
echo "=========================================================================="
if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}✓ All Checks Passed!${NC}"
    echo "=========================================================================="
    echo ""
    echo "Webhook plugin is properly built and installed!"
    echo ""
    echo "File locations:"
    echo "  Source:      ${WEBHOOK_SRC}"
    echo "  Build:       ${BUILD_DIR}"
    echo "  Installed:   ${WEBHOOK_INSTALL_DIR}"
    echo "  Config:      ${WEBHOOK_CONFIG}"
    echo ""
    echo "Test it:"
    echo "  1. tail -f /var/log/srgan-watchdog.log"
    echo "  2. Play a video in Jellyfin"
    echo "  3. Check for: \"Path\": \"/media/movies/Example.mkv\""
else
    echo -e "${RED}✗ ${ISSUES} Issue(s) Found${NC}"
    echo "=========================================================================="
    echo ""
    echo "Please fix the issues above."
    echo ""
    echo "Common fixes:"
    echo "  1. Setup source: ./scripts/setup_webhook_source.sh"
    echo "  2. Apply patch: ./scripts/patch_webhook_path.sh"
    echo "  3. Build: cd ${WEBHOOK_SRC} && dotnet build -c Release"
    echo "  4. Install: sudo ./scripts/install_all.sh"
fi
echo ""

exit $ISSUES
