#!/bin/bash
#
# Fix Jellyfin URL in installed watchdog service
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENV_FILE="/etc/default/srgan-watchdog-api"

echo "=========================================================================="
echo "Fix Jellyfin URL in Watchdog Service"
echo "=========================================================================="
echo ""

# Check if service is installed
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}✗ Watchdog service not installed${NC}"
    echo "Run: sudo ./scripts/install_all.sh"
    exit 1
fi

# Show current URL
CURRENT_URL=$(grep "^JELLYFIN_URL=" "$ENV_FILE" | cut -d= -f2)
echo "Current URL: ${CURRENT_URL}"
echo ""

# Try to detect Jellyfin port
echo "Detecting Jellyfin port..."
DETECTED_PORT=$(ss -tlnp 2>/dev/null | grep jellyfin | grep LISTEN | head -1 | awk '{print $4}' | awk -F: '{print $NF}')

if [[ -z "$DETECTED_PORT" ]]; then
    DETECTED_PORT=$(netstat -tlnp 2>/dev/null | grep jellyfin | grep LISTEN | head -1 | awk '{print $4}' | awk -F: '{print $NF}')
fi

if [[ -n "$DETECTED_PORT" ]]; then
    echo -e "${GREEN}✓ Detected Jellyfin on port: ${DETECTED_PORT}${NC}"
    DEFAULT_URL="http://localhost:${DETECTED_PORT}"
else
    echo -e "${YELLOW}⚠ Could not auto-detect port${NC}"
    DEFAULT_URL="http://localhost:8096"
fi

echo ""

# Prompt for new URL
read -p "Enter new Jellyfin URL [${DEFAULT_URL}]: " NEW_URL
NEW_URL="${NEW_URL:-$DEFAULT_URL}"

# Test connectivity
echo ""
echo "Testing connectivity to: ${NEW_URL}"
if curl -s -f "${NEW_URL}/System/Info/Public" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Jellyfin accessible${NC}"
else
    echo -e "${YELLOW}⚠ Could not connect to ${NEW_URL}${NC}"
    echo ""
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update environment file
echo ""
echo "Updating ${ENV_FILE}..."
sudo sed -i "s|^JELLYFIN_URL=.*|JELLYFIN_URL=${NEW_URL}|" "$ENV_FILE"
echo -e "${GREEN}✓ URL updated${NC}"

# Restart service
echo ""
echo "Restarting watchdog service..."
sudo systemctl restart srgan-watchdog-api

# Wait for service to start
sleep 2

if systemctl is-active --quiet srgan-watchdog-api; then
    echo -e "${GREEN}✓ Service restarted successfully${NC}"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check logs: sudo journalctl -u srgan-watchdog-api -n 50"
    exit 1
fi

# Test API
echo ""
echo "Testing watchdog API..."
if curl -s -f http://localhost:5432/status >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Watchdog API responding${NC}"
    
    # Show status
    STATUS=$(curl -s http://localhost:5432/status)
    JELLYFIN_OK=$(echo "$STATUS" | grep -o '"jellyfin_reachable": [^,}]*' | cut -d: -f2 | tr -d ' ')
    
    if [[ "$JELLYFIN_OK" == "true" ]]; then
        echo -e "${GREEN}✓ Jellyfin API reachable${NC}"
    else
        echo -e "${YELLOW}⚠ Jellyfin API not reachable${NC}"
        echo "  Check API key and URL"
    fi
else
    echo -e "${YELLOW}⚠ Watchdog API not responding yet${NC}"
fi

echo ""
echo "=========================================================================="
echo -e "${GREEN}Jellyfin URL Updated!${NC}"
echo "=========================================================================="
echo ""
echo "Old URL: ${CURRENT_URL}"
echo "New URL: ${NEW_URL}"
echo ""
echo "Test it:"
echo "  1. Play a video in Jellyfin"
echo "  2. Check logs: sudo journalctl -u srgan-watchdog-api -f"
echo "  3. Should see: 'Found playing item: ... (path)'"
echo ""
