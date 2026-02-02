#!/bin/bash
#
# Verify Webhook {{Path}} Variable is Working
#

echo "=========================================================================="
echo "Webhook {{Path}} Variable Verification"
echo "=========================================================================="
echo ""

# Check if webhook plugin is installed
WEBHOOK_DLL="/var/lib/jellyfin/plugins/Webhook/Jellyfin.Plugin.Webhook.dll"
if [ ! -f "${WEBHOOK_DLL}" ]; then
    echo "✗ Webhook plugin not installed at ${WEBHOOK_DLL}"
    exit 1
fi

echo "✓ Webhook plugin installed"
echo ""

# Check webhook configuration
WEBHOOK_CONFIG="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"
if [ ! -f "${WEBHOOK_CONFIG}" ]; then
    echo "✗ Webhook configuration not found at ${WEBHOOK_CONFIG}"
    exit 1
fi

echo "✓ Webhook configuration exists"
echo ""

# Check if {{Path}} is in the template
echo "Checking webhook configuration for {{Path}} variable..."
if grep -q "{{Path}}" "${WEBHOOK_CONFIG}"; then
    echo "✓ {{Path}} variable found in webhook configuration"
    echo ""
    echo "Template excerpt:"
    grep -A 5 -B 5 "{{Path}}" "${WEBHOOK_CONFIG}" | head -15
else
    echo "✗ {{Path}} variable NOT found in webhook configuration"
    echo ""
    echo "Current template:"
    grep -A 10 "<Template>" "${WEBHOOK_CONFIG}" || echo "No template found"
    echo ""
    echo "To fix, run:"
    echo "  sudo python3 scripts/configure_webhook.py http://localhost:5000 ${WEBHOOK_CONFIG}"
    exit 1
fi

echo ""
echo "=========================================================================="
echo "Testing Webhook with Mock Data"
echo "=========================================================================="
echo ""

# Check if watchdog is running
if ! systemctl is-active --quiet srgan-watchdog 2>/dev/null; then
    echo "⚠ Watchdog service not running - starting temporarily for test..."
    echo "  (Webhook will send to localhost:5000)"
fi

# Check watchdog logs
echo "Checking recent watchdog logs for webhook data..."
if [ -f "/var/log/srgan-watchdog.log" ]; then
    echo ""
    echo "Recent webhook data (last 20 lines):"
    tail -20 /var/log/srgan-watchdog.log | grep -E "Path|webhook|Received" || echo "No recent webhook data found"
else
    echo "Watchdog log not found at /var/lib/srgan-watchdog.log"
fi

echo ""
echo "=========================================================================="
echo "DataObjectHelpers.cs Source Check"
echo "=========================================================================="
echo ""

# Check the source code if available
SOURCE_FILE="jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs"
if [ -f "${SOURCE_FILE}" ]; then
    echo "Checking DataObjectHelpers.cs for Path property..."
    if grep -q '"Path".*item\.Path' "${SOURCE_FILE}"; then
        echo "✓ Path property IS exposed in DataObjectHelpers.cs"
        echo ""
        echo "Implementation:"
        grep -A 3 -B 1 '"Path".*item\.Path' "${SOURCE_FILE}"
    else
        echo "✗ Path property NOT found in DataObjectHelpers.cs"
        echo ""
        echo "The webhook plugin needs to be patched!"
        echo "Run: ./scripts/patch_webhook_path.sh"
        exit 1
    fi
else
    echo "⚠ Source file not available for checking"
    echo "  (This is OK if you're only checking the installed plugin)"
fi

echo ""
echo "=========================================================================="
echo "Manual Test Instructions"
echo "=========================================================================="
echo ""
echo "To manually test the webhook:"
echo ""
echo "1. Start monitoring watchdog logs:"
echo "   tail -f /var/log/srgan-watchdog.log"
echo ""
echo "2. In Jellyfin, play a video (movie or episode)"
echo ""
echo "3. Check the logs for webhook data containing:"
echo "   - \"Path\": \"/path/to/video.mkv\""
echo "   - NOT \"Path\": \"\""
echo ""
echo "4. If Path is empty, the plugin needs to be rebuilt with the patch:"
echo "   cd /root/Jellyfin-SRGAN-Plugin"
echo "   ./scripts/patch_webhook_path.sh"
echo "   sudo ./scripts/install_all.sh"
echo ""
echo "=========================================================================="
echo ""
