#!/usr/bin/env bash
# Helper script to manage the SRGAN watchdog systemd service

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICE_NAME="srgan-watchdog.service"

show_usage() {
    echo "SRGAN Watchdog Service Manager"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      Show service status"
    echo "  start       Start the service"
    echo "  stop        Stop the service"
    echo "  restart     Restart the service"
    echo "  logs        Show live logs (follow)"
    echo "  recent      Show recent logs"
    echo "  enable      Enable service to start on boot"
    echo "  disable     Disable service from starting on boot"
    echo "  install     Install the systemd service"
    echo "  uninstall   Remove the systemd service"
    echo "  test        Test webhook connectivity"
    echo "  health      Check webhook health"
    echo ""
}

check_installed() {
    if ! systemctl list-unit-files | grep -q "${SERVICE_NAME}"; then
        echo -e "${RED}✗ Service not installed${NC}"
        echo ""
        echo "Install with:"
        echo "  sudo ./install_systemd_watchdog.sh"
        echo "  or"
        echo "  $0 install"
        return 1
    fi
    return 0
}

status_service() {
    if ! check_installed; then
        return 1
    fi
    
    echo "=========================================================================="
    echo "SRGAN Watchdog Service Status"
    echo "=========================================================================="
    echo ""
    
    sudo systemctl status "${SERVICE_NAME}" --no-pager || true
    
    echo ""
    echo "Quick status:"
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e "  State: ${GREEN}active (running)${NC}"
    else
        echo -e "  State: ${RED}inactive (stopped)${NC}"
    fi
    
    if systemctl is-enabled --quiet "${SERVICE_NAME}"; then
        echo -e "  Enabled: ${GREEN}yes${NC} (starts on boot)"
    else
        echo -e "  Enabled: ${YELLOW}no${NC} (manual start required)"
    fi
}

start_service() {
    if ! check_installed; then
        return 1
    fi
    
    echo "Starting ${SERVICE_NAME}..."
    sudo systemctl start "${SERVICE_NAME}"
    sleep 2
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e "${GREEN}✓${NC} Service started successfully"
        test_health
    else
        echo -e "${RED}✗${NC} Failed to start service"
        echo ""
        echo "Check logs:"
        echo "  $0 recent"
        return 1
    fi
}

stop_service() {
    if ! check_installed; then
        return 1
    fi
    
    echo "Stopping ${SERVICE_NAME}..."
    sudo systemctl stop "${SERVICE_NAME}"
    echo -e "${GREEN}✓${NC} Service stopped"
}

restart_service() {
    if ! check_installed; then
        return 1
    fi
    
    echo "Restarting ${SERVICE_NAME}..."
    sudo systemctl restart "${SERVICE_NAME}"
    sleep 2
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e "${GREEN}✓${NC} Service restarted successfully"
        test_health
    else
        echo -e "${RED}✗${NC} Failed to restart service"
        return 1
    fi
}

show_logs() {
    if ! check_installed; then
        return 1
    fi
    
    echo "Showing live logs for ${SERVICE_NAME}"
    echo "Press Ctrl+C to exit"
    echo ""
    sudo journalctl -u "${SERVICE_NAME}" -f
}

show_recent() {
    if ! check_installed; then
        return 1
    fi
    
    echo "Recent logs for ${SERVICE_NAME}:"
    echo ""
    sudo journalctl -u "${SERVICE_NAME}" -n 50 --no-pager
}

enable_service() {
    if ! check_installed; then
        return 1
    fi
    
    echo "Enabling ${SERVICE_NAME} to start on boot..."
    sudo systemctl enable "${SERVICE_NAME}"
    echo -e "${GREEN}✓${NC} Service enabled"
}

disable_service() {
    if ! check_installed; then
        return 1
    fi
    
    echo "Disabling ${SERVICE_NAME} from starting on boot..."
    sudo systemctl disable "${SERVICE_NAME}"
    echo -e "${GREEN}✓${NC} Service disabled"
}

install_service() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
    
    if [[ ! -f "${SCRIPT_DIR}/install_systemd_watchdog.sh" ]]; then
        echo -e "${RED}✗ Installation script not found${NC}"
        return 1
    fi
    
    echo "Installing ${SERVICE_NAME}..."
    sudo bash "${SCRIPT_DIR}/install_systemd_watchdog.sh" "${PROJECT_DIR}"
}

uninstall_service() {
    if ! check_installed; then
        echo -e "${YELLOW}Service not installed, nothing to uninstall${NC}"
        return 0
    fi
    
    echo "Uninstalling ${SERVICE_NAME}..."
    
    # Stop if running
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo "Stopping service..."
        sudo systemctl stop "${SERVICE_NAME}"
    fi
    
    # Disable if enabled
    if systemctl is-enabled --quiet "${SERVICE_NAME}"; then
        echo "Disabling service..."
        sudo systemctl disable "${SERVICE_NAME}"
    fi
    
    # Remove service file
    echo "Removing service file..."
    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}"
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✓${NC} Service uninstalled"
}

test_webhook() {
    echo "Testing webhook connectivity..."
    echo ""
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [[ -f "${SCRIPT_DIR}/test_webhook.py" ]]; then
        python3 "${SCRIPT_DIR}/test_webhook.py"
    else
        echo "Running basic health check..."
        test_health
    fi
}

test_health() {
    echo ""
    echo "Checking webhook health..."
    
    if curl -s http://localhost:5000/health > /dev/null 2>&1; then
        RESPONSE=$(curl -s http://localhost:5000/health)
        echo -e "${GREEN}✓${NC} Webhook is responding"
        echo ""
        echo "Response:"
        echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}"
    else
        echo -e "${RED}✗${NC} Webhook is not responding"
        echo ""
        echo "Possible causes:"
        echo "  - Service not running (check: $0 status)"
        echo "  - Port 5000 blocked by firewall"
        echo "  - Service still starting (wait a few seconds)"
    fi
}

# Main command handling
COMMAND="${1:-}"

case "${COMMAND}" in
    status)
        status_service
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    logs)
        show_logs
        ;;
    recent)
        show_recent
        ;;
    enable)
        enable_service
        ;;
    disable)
        disable_service
        ;;
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    test)
        test_webhook
        ;;
    health)
        test_health
        ;;
    "")
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown command: ${COMMAND}${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
