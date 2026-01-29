#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
UNIT_PATH="/etc/systemd/system/srgan-watchdog.service"
CURRENT_USER="${SUDO_USER:-${USER}}"
PYTHON_BIN="$(which python3)"

echo "=========================================================================="
echo "SRGAN Watchdog Systemd Service Installation"
echo "=========================================================================="
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run with sudo${NC}" 
   echo "Usage: sudo ./install_systemd_watchdog.sh [repo_dir]"
   exit 1
fi

echo "Repository directory: ${REPO_DIR}"
echo "Service will run as user: ${CURRENT_USER}"
echo "Python binary: ${PYTHON_BIN}"
echo ""

# Prerequisites check
echo "Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker is not installed or not in PATH.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✓${NC} Docker installed"

if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker Compose v2 not found. Install or upgrade Docker.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✓${NC} Docker Compose v2 installed"

# Check if Flask is installed for the user
if ! su - "${CURRENT_USER}" -c "${PYTHON_BIN} -c 'import flask' 2>/dev/null"; then
  echo -e "${YELLOW}⚠${NC} Flask not installed for user ${CURRENT_USER}"
  echo "Installing Flask and requests..."
  su - "${CURRENT_USER}" -c "${PYTHON_BIN} -m pip install --user flask requests" || {
    echo -e "${RED}✗ Failed to install Flask. Install manually: pip3 install flask requests${NC}"
    exit 1
  }
  echo -e "${GREEN}✓${NC} Flask installed"
else
  echo -e "${GREEN}✓${NC} Flask already installed"
fi

# Check if watchdog.py exists
if [[ ! -f "${REPO_DIR}/scripts/watchdog.py" ]]; then
  echo -e "${RED}✗ watchdog.py not found at ${REPO_DIR}/scripts/watchdog.py${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} watchdog.py found"

# Create cache directory
mkdir -p "${REPO_DIR}/cache"
chown "${CURRENT_USER}:${CURRENT_USER}" "${REPO_DIR}/cache"
echo -e "${GREEN}✓${NC} Cache directory ready"

# Detect environment variables from docker-compose.yml
UPSCALED_DIR="/data/upscaled"
if grep -q "UPSCALED_DIR" "${REPO_DIR}/docker-compose.yml" 2>/dev/null; then
  UPSCALED_DIR=$(grep "UPSCALED_DIR" "${REPO_DIR}/docker-compose.yml" | head -1 | cut -d'=' -f2 | tr -d ' ')
fi

echo ""
echo "Creating systemd service..."

# Create the systemd service file
sudo tee "${UNIT_PATH}" >/dev/null <<EOF
[Unit]
Description=SRGAN Watchdog - Jellyfin Webhook Listener for Video Upscaling
Documentation=file://${REPO_DIR}/README.md
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${REPO_DIR}

# Environment variables
Environment="UPSCALED_DIR=${UPSCALED_DIR}"
Environment="SRGAN_QUEUE_FILE=${REPO_DIR}/cache/queue.jsonl"
Environment="PYTHONUNBUFFERED=1"

# Ensure Docker container is ready (optional - comment out if not needed)
ExecStartPre=-/usr/bin/docker compose -f ${REPO_DIR}/docker-compose.yml up -d srgan-upscaler

# Start the watchdog
ExecStart=${PYTHON_BIN} ${REPO_DIR}/scripts/watchdog.py

# Restart configuration
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=srgan-watchdog

# Security hardening (optional)
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓${NC} Service file created at ${UNIT_PATH}"

# Reload systemd
echo ""
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
echo -e "${GREEN}✓${NC} Systemd daemon reloaded"

# Enable the service
echo ""
echo "Enabling service to start on boot..."
sudo systemctl enable srgan-watchdog.service
echo -e "${GREEN}✓${NC} Service enabled"

# Start the service
echo ""
echo "Starting service..."
sudo systemctl start srgan-watchdog.service

# Wait a moment for service to start
sleep 2

# Check status
if sudo systemctl is-active --quiet srgan-watchdog.service; then
  echo -e "${GREEN}✓${NC} Service started successfully"
else
  echo -e "${RED}✗${NC} Service failed to start"
  echo ""
  echo "Check logs with:"
  echo "  sudo journalctl -u srgan-watchdog.service -n 50"
  exit 1
fi

# Test the webhook
echo ""
echo "Testing webhook health check..."
sleep 1
if curl -s http://localhost:5000/health > /dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} Webhook is responding"
else
  echo -e "${YELLOW}⚠${NC} Webhook may not be responding yet (give it a few seconds)"
fi

echo ""
echo "=========================================================================="
echo "Installation Complete!"
echo "=========================================================================="
echo ""
echo "Service: srgan-watchdog.service"
echo "Status: $(systemctl is-active srgan-watchdog.service)"
echo ""
echo "Useful commands:"
echo "  Status:        sudo systemctl status srgan-watchdog.service"
echo "  Stop:          sudo systemctl stop srgan-watchdog.service"
echo "  Start:         sudo systemctl start srgan-watchdog.service"
echo "  Restart:       sudo systemctl restart srgan-watchdog.service"
echo "  Logs:          sudo journalctl -u srgan-watchdog.service -f"
echo "  Recent logs:   sudo journalctl -u srgan-watchdog.service -n 50"
echo "  Disable:       sudo systemctl disable srgan-watchdog.service"
echo ""
echo "Webhook endpoint: http://localhost:5000/upscale-trigger"
echo "Health check:     http://localhost:5000/health"
echo ""
