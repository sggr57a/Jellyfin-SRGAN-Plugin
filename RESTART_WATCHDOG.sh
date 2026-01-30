#!/bin/bash
#
# Restart the watchdog service after configuration changes
#

echo "╔══════════════════════════════════════════════╗"
echo "║    Restarting SRGAN Watchdog Service         ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Check if service exists
if systemctl list-unit-files | grep -q "srgan-watchdog.service"; then
    echo "✓ Service found: srgan-watchdog"
    echo ""
    echo "Restarting service..."
    sudo systemctl restart srgan-watchdog
    
    sleep 2
    
    echo ""
    echo "Checking status..."
    sudo systemctl status srgan-watchdog --no-pager -l
    
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "✅ Service restarted!"
    echo ""
    echo "View logs:"
    echo "  sudo journalctl -u srgan-watchdog -f"
    echo ""
    echo "Test webhook:"
    echo "  curl http://localhost:5000/health"
    echo ""
else
    echo "❌ Service not found: srgan-watchdog"
    echo ""
    echo "Install service first:"
    echo "  ./scripts/install_all.sh"
    echo ""
    echo "Or run manually:"
    echo "  python3 scripts/watchdog.py"
    exit 1
fi
