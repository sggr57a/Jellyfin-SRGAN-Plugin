#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
UNIT_PATH="/etc/systemd/system/srgan-watchdog-api.service"
CURRENT_USER="${SUDO_USER:-${USER}}"
PYTHON_BIN="$(which python3)"

echo "=========================================================================="
echo "SRGAN Watchdog API-Based Service Installation"
echo "=========================================================================="
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run with sudo${NC}" 
   echo "Usage: sudo ./install_api_watchdog.sh [repo_dir]"
   exit 1
fi

echo "Repository directory: ${REPO_DIR}"
echo "Service will run as user: ${CURRENT_USER}"
echo "Python binary: ${PYTHON_BIN}"
echo ""

# Prerequisites check
echo "Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker is not installed${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} Docker installed"

if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker Compose v2 not found${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} Docker Compose v2 installed"

# Check if requests library is installed
if ! ${PYTHON_BIN} -c 'import requests' 2>/dev/null; then
  echo -e "${YELLOW}⚠${NC} Python requests library not installed"
  echo "Installing requests..."
  ${PYTHON_BIN} -m pip install --user requests || {
    echo -e "${RED}✗ Failed to install requests${NC}"
    exit 1
  }
  echo -e "${GREEN}✓${NC} Requests installed"
else
  echo -e "${GREEN}✓${NC} Python requests library installed"
fi

echo ""

# Get Jellyfin API key
echo -e "${BLUE}Jellyfin API Key Configuration${NC}"
echo ""
echo "The API-based watchdog needs a Jellyfin API key to query active sessions."
echo ""
echo "To create an API key:"
echo "  1. Open Jellyfin Dashboard"
echo "  2. Go to: Dashboard → Advanced → API Keys"
echo "  3. Click '+' button"
echo "  4. Application name: SRGAN Watchdog"
echo "  5. Copy the generated key"
echo ""

# Check if API key already exists in environment
if [[ -f "/etc/default/srgan-watchdog-api" ]]; then
    echo "Found existing configuration: /etc/default/srgan-watchdog-api"
    source /etc/default/srgan-watchdog-api
    if [[ -n "${JELLYFIN_API_KEY:-}" ]]; then
        echo -e "${GREEN}✓${NC} API key already configured"
        echo ""
        read -p "Use existing API key? (y/n): " USE_EXISTING
        if [[ "${USE_EXISTING}" =~ ^[Yy] ]]; then
            API_KEY="${JELLYFIN_API_KEY}"
        else
            read -p "Enter Jellyfin API key: " API_KEY
        fi
    else
        read -p "Enter Jellyfin API key: " API_KEY
    fi
else
    read -p "Enter Jellyfin API key: " API_KEY
fi

if [[ -z "${API_KEY}" ]]; then
    echo -e "${RED}✗ API key is required${NC}"
    exit 1
fi

# Get Jellyfin URL
read -p "Enter Jellyfin URL [http://localhost:8096]: " JELLYFIN_URL
JELLYFIN_URL="${JELLYFIN_URL:-http://localhost:8096}"

echo ""
echo "Testing API connection..."

# Test API connectivity
if curl -s -f -H "X-Emby-Token: ${API_KEY}" "${JELLYFIN_URL}/Sessions" > /dev/null; then
    echo -e "${GREEN}✓${NC} Successfully connected to Jellyfin API"
else
    echo -e "${YELLOW}⚠${NC} Could not connect to Jellyfin API"
    echo "The service will still be installed, but verify:"
    echo "  - Jellyfin is running"
    echo "  - URL is correct: ${JELLYFIN_URL}"
    echo "  - API key is valid"
fi

echo ""

# Create environment file
echo "Creating environment configuration..."
cat > /etc/default/srgan-watchdog-api << EOF
# Jellyfin API Configuration
JELLYFIN_URL=${JELLYFIN_URL}
JELLYFIN_API_KEY=${API_KEY}

# Watchdog Configuration
UPSCALED_DIR=/mnt/media/upscaled
SRGAN_QUEUE_FILE=${REPO_DIR}/cache/queue.jsonl
ENABLE_HLS_STREAMING=1
HLS_SERVER_HOST=localhost
HLS_SERVER_PORT=8080
EOF

chmod 600 /etc/default/srgan-watchdog-api
echo -e "${GREEN}✓${NC} Environment file created: /etc/default/srgan-watchdog-api"
echo ""

# Create systemd service
echo "Creating systemd service..."
cat > "${UNIT_PATH}" << EOF
[Unit]
Description=SRGAN Watchdog API-Based Webhook Listener
After=network.target docker.service jellyfin.service
Wants=jellyfin.service

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${REPO_DIR}

# Load environment from file
EnvironmentFile=/etc/default/srgan-watchdog-api

ExecStart=${PYTHON_BIN} ${REPO_DIR}/scripts/watchdog_api.py

# Restart on failure
Restart=always
RestartSec=5

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=srgan-watchdog-api

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓${NC} Systemd service created: ${UNIT_PATH}"
echo ""

# Stop old watchdog if running
if systemctl is-active --quiet srgan-watchdog; then
    echo "Stopping old template-based watchdog..."
    systemctl stop srgan-watchdog
    systemctl disable srgan-watchdog
    echo -e "${GREEN}✓${NC} Old watchdog stopped"
fi

# Reload systemd and enable service
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable srgan-watchdog-api
systemctl start srgan-watchdog-api

echo ""
echo "Waiting for service to start..."
sleep 2

# Check service status
if systemctl is-active --quiet srgan-watchdog-api; then
    echo -e "${GREEN}✓${NC} Service is running"
    echo ""
    
    # Test webhook endpoint
    echo "Testing webhook endpoint..."
    if curl -s -f -X POST http://localhost:5432/status > /dev/null; then
        echo -e "${GREEN}✓${NC} Webhook endpoint responding"
    else
        echo -e "${YELLOW}⚠${NC} Webhook endpoint not responding yet"
    fi
else
    echo -e "${RED}✗${NC} Service failed to start"
    echo ""
    echo "Check logs:"
    echo "  sudo journalctl -u srgan-watchdog-api -n 50"
    exit 1
fi

echo ""
echo "=========================================================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "=========================================================================="
echo ""
echo "Service: srgan-watchdog-api"
echo "Status:  $(systemctl is-active srgan-watchdog-api)"
echo ""
echo "Commands:"
echo "  Check status:  sudo systemctl status srgan-watchdog-api"
echo "  View logs:     sudo journalctl -u srgan-watchdog-api -f"
echo "  Restart:       sudo systemctl restart srgan-watchdog-api"
echo "  Stop:          sudo systemctl stop srgan-watchdog-api"
echo ""
echo "API Endpoints:"
echo "  Webhook:       http://localhost:5432/upscale-trigger"
echo "  Status:        http://localhost:5432/status"
echo "  Sessions:      http://localhost:5432/sessions"
echo "  Now Playing:   http://localhost:5432/playing"
echo ""
echo "Configuration:"
echo "  File:          /etc/default/srgan-watchdog-api"
echo "  Jellyfin URL:  ${JELLYFIN_URL}"
echo "  API Key:       $(echo ${API_KEY} | cut -c1-8)..."
echo ""
echo "Next Steps:"
echo "  1. Configure Jellyfin webhook to POST to:"
echo "     http://localhost:5432/upscale-trigger"
echo "  2. Play a video in Jellyfin"
echo "  3. Monitor logs: sudo journalctl -u srgan-watchdog-api -f"
echo ""
echo "Note: This uses Jellyfin API to get file paths, not {{Path}} variable!"
echo "      The webhook payload content doesn't matter - we query the API."
echo ""
