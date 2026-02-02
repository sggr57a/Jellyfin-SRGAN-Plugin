#!/bin/bash
#
# FIX WEBHOOK TEMPLATE - Ensure {{Path}} is in configuration RIGHT NOW
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
echo "FIXING WEBHOOK TEMPLATE - Adding {{Path}} Variable"
echo "=========================================================================="
echo ""

WEBHOOK_CONFIG="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"

# Check if config exists
if [[ ! -f "${WEBHOOK_CONFIG}" ]]; then
    echo -e "${YELLOW}Webhook configuration does not exist. Creating...${NC}"
    sudo python3 "${SCRIPT_DIR}/configure_webhook.py" http://localhost:5000 "${WEBHOOK_CONFIG}"
    echo ""
fi

# Check current state
echo "Checking current webhook configuration..."
if grep -q "{{Path}}" "${WEBHOOK_CONFIG}"; then
    echo -e "${GREEN}✓ Template already includes {{Path}}${NC}"
    echo ""
    echo "Current template (decoded):"
    grep "<Template>" "${WEBHOOK_CONFIG}" | sed 's/<Template>//;s/<\/Template>//' | base64 -d | python3 -m json.tool 2>/dev/null || echo "Could not decode"
    exit 0
fi

echo -e "${RED}✗ Template does NOT include {{Path}}${NC}"
echo ""

# Backup current config
BACKUP="${WEBHOOK_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
sudo cp "${WEBHOOK_CONFIG}" "${BACKUP}"
echo "Backed up to: ${BACKUP}"
echo ""

# Reconfigure with {{Path}}
echo "Reconfiguring webhook with {{Path}} variable..."
if sudo python3 "${SCRIPT_DIR}/configure_webhook.py" http://localhost:5000 "${WEBHOOK_CONFIG}"; then
    echo -e "${GREEN}✓ Webhook reconfigured successfully${NC}"
else
    echo -e "${RED}✗ Failed to reconfigure webhook${NC}"
    echo "Restoring backup..."
    sudo cp "${BACKUP}" "${WEBHOOK_CONFIG}"
    exit 1
fi

echo ""

# Verify the fix
echo "Verifying {{Path}} is now in template..."
if grep -q "{{Path}}" "${WEBHOOK_CONFIG}"; then
    echo -e "${GREEN}✓✓✓ SUCCESS! {{Path}} is now in the template! ✓✓✓${NC}"
    echo ""
    echo "Template content (decoded):"
    grep "<Template>" "${WEBHOOK_CONFIG}" | sed 's/<Template>//;s/<\/Template>//' | base64 -d | python3 -m json.tool 2>/dev/null || echo "Could not decode"
    echo ""
    echo "Restarting Jellyfin to apply changes..."
    sudo systemctl restart jellyfin
    sleep 5
    
    if systemctl is-active --quiet jellyfin; then
        echo -e "${GREEN}✓ Jellyfin restarted successfully${NC}"
    else
        echo -e "${RED}✗ Jellyfin failed to restart${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ {{Path}} still not in template after reconfiguration!${NC}"
    echo ""
    echo "This may indicate an issue with configure_webhook.py"
    echo "Checking the script..."
    if grep -q '"Path"' "${SCRIPT_DIR}/configure_webhook.py"; then
        echo "✓ configure_webhook.py includes Path in its template"
        echo ""
        echo "Manual fix: Check Jellyfin Dashboard → Plugins → Webhook"
        echo "Template should include: {\"Path\":\"{{Path}}\",\"Name\":\"{{Name}}\",...}"
    else
        echo "✗ configure_webhook.py may be missing Path in template!"
    fi
    exit 1
fi

echo ""
echo "=========================================================================="
echo "TEMPLATE FIXED!"
echo "=========================================================================="
echo ""
echo "Test it now:"
echo "  1. tail -f /var/log/srgan-watchdog.log"
echo "  2. Play a video in Jellyfin"
echo "  3. Check logs for: \"Path\": \"/media/movies/Example.mkv\""
echo ""
