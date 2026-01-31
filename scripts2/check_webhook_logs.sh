#!/bin/bash
#
# Extract and diagnose the latest webhook payload from logs
#

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          WEBHOOK LOG CHECKER & DIAGNOSTIC                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if systemd service exists
if ! systemctl list-unit-files | grep -q "srgan-watchdog.service"; then
    echo "❌ srgan-watchdog service not found"
    echo ""
    echo "Are you running watchdog manually?"
    echo "If so, check the terminal output where you ran:"
    echo "  python3 scripts/watchdog.py"
    echo ""
    exit 1
fi

echo "Checking watchdog service status..."
if ! systemctl is-active --quiet srgan-watchdog; then
    echo "⚠️  WARNING: Watchdog service is not running!"
    echo ""
    echo "Start it with:"
    echo "  sudo systemctl start srgan-watchdog"
    echo ""
    echo "Or run manually:"
    echo "  python3 scripts/watchdog.py"
    echo ""
    exit 1
fi

echo "✓ Watchdog service is running"
echo ""

# Get recent logs
echo "Fetching recent logs..."
LOGS=$(sudo journalctl -u srgan-watchdog -n 200 --no-pager 2>/dev/null)

if [ -z "$LOGS" ]; then
    echo "❌ No logs found"
    echo ""
    echo "Try:"
    echo "  sudo journalctl -u srgan-watchdog"
    echo ""
    exit 1
fi

echo "✓ Got logs"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if any webhooks were received
if ! echo "$LOGS" | grep -q "Webhook received"; then
    echo "❌ NO WEBHOOKS RECEIVED"
    echo ""
    echo "This means Jellyfin is NOT sending webhooks to the watchdog."
    echo ""
    echo "POSSIBLE CAUSES:"
    echo ""
    echo "1. Webhook URL is wrong"
    echo "   Check: http://YOUR_SERVER_IP:5000/upscale-trigger"
    echo "   Test: curl http://localhost:5000/health"
    echo ""
    echo "2. Firewall blocking requests"
    echo "   Check: sudo ufw status"
    echo ""
    echo "3. Webhook not enabled in Jellyfin"
    echo "   Dashboard → Plugins → Webhooks → Check webhook is enabled"
    echo ""
    echo "4. Wrong Notification Type / Item Type (webhook never fires)"
    echo "   Must check: Playback Start, Movie, Episode"
    echo ""
    exit 1
fi

echo "✓ Webhooks ARE being received"
echo ""

# Extract the most recent payload
echo "Extracting most recent webhook payload..."
echo ""

# Get lines between "Full payload:" and the next "Extracted file path" or error
PAYLOAD=$(echo "$LOGS" | grep -A 30 "Full payload:" | tail -n 35 | head -n 30)

if [ -z "$PAYLOAD" ]; then
    echo "❌ Could not extract payload from logs"
    echo ""
    echo "View full logs manually:"
    echo "  sudo journalctl -u srgan-watchdog -n 100"
    echo ""
    exit 1
fi

echo "Latest webhook payload:"
echo "───────────────────────────────────────────────────────────────"
echo "$PAYLOAD" | grep -A 20 "Full payload:"
echo "───────────────────────────────────────────────────────────────"
echo ""

# Check for common issues in logs
echo "Analyzing logs for issues..."
echo ""

# Check for empty path
if echo "$LOGS" | tail -n 50 | grep -q '"Path": ""'; then
    echo "❌ PROBLEM DETECTED: Empty Path"
    echo ""
    echo "   The webhook payload has an EMPTY path:"
    echo '   "Path": ""'
    echo ""
    echo "   This means Jellyfin is NOT filling template variables."
    echo ""
    echo "   ROOT CAUSE: Missing checkboxes in Jellyfin webhook config"
    echo ""
    echo "   ╔══════════════════════════════════════════════════════════╗"
    echo "   ║  FIX: Check these boxes in Jellyfin webhook settings    ║"
    echo "   ╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "   Go to: Dashboard → Plugins → Webhooks → Edit webhook"
    echo ""
    echo "   Check these boxes:"
    echo "   ☑ Playback Start      (Notification Type)"
    echo "   ☑ Movie               (Item Type)"
    echo "   ☑ Episode             (Item Type)"
    echo ""
    echo "   Then click SAVE and test again."
    echo ""
    echo "   Complete guide: IMMEDIATE_FIX.md"
    echo ""
    exit 1
fi

# Check for content-type issues
if echo "$LOGS" | tail -n 50 | grep -q "Content-Type is"; then
    if echo "$LOGS" | tail -n 50 | grep -q "Content-Type is 'text/plain'"; then
        echo "⚠️  WARNING: Wrong Content-Type"
        echo ""
        echo "   Content-Type is 'text/plain' but should be 'application/json'"
        echo ""
        echo "   In Jellyfin webhook settings:"
        echo "   Request Content Type: application/json"
        echo ""
    fi
fi

# Check for file not found
if echo "$LOGS" | tail -n 50 | grep -q "File not found"; then
    MISSING_FILE=$(echo "$LOGS" | tail -n 50 | grep "File not found" | tail -n 1 | sed 's/.*File not found: //')
    echo "⚠️  WARNING: File not found"
    echo ""
    echo "   Webhook is working, but file doesn't exist:"
    echo "   $MISSING_FILE"
    echo ""
    echo "   Check if file exists on watchdog host:"
    echo "   ls -lh \"$MISSING_FILE\""
    echo ""
fi

# Check for success
if echo "$LOGS" | tail -n 50 | grep -q "✓ File exists"; then
    SUCCESS_FILE=$(echo "$LOGS" | tail -n 50 | grep "✓ File exists" | tail -n 1 | sed 's/.*✓ File exists: //')
    echo "✅ SUCCESS: Webhook is working!"
    echo ""
    echo "   Latest file processed:"
    echo "   $SUCCESS_FILE"
    echo ""
    echo "   The webhook configuration is correct."
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Full recent logs:"
echo "  sudo journalctl -u srgan-watchdog -n 100"
echo ""
echo "Watch live logs:"
echo "  sudo journalctl -u srgan-watchdog -f"
echo ""
echo "Diagnose specific payload:"
echo "  python3 scripts/diagnose_webhook.py"
echo ""
