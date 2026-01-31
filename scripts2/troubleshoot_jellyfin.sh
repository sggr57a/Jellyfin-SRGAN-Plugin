#!/bin/bash
#
# Troubleshoot Jellyfin web interface loading issues
#

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        JELLYFIN WEB INTERFACE TROUBLESHOOTER                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if Jellyfin is running
echo "Step 1: Check Jellyfin service status"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if systemctl is-active --quiet jellyfin; then
    echo "✓ Jellyfin service is RUNNING"
    systemctl status jellyfin --no-pager -l | head -n 10
else
    echo "❌ Jellyfin service is NOT RUNNING"
    echo ""
    echo "Start it with:"
    echo "  sudo systemctl start jellyfin"
    echo ""
    echo "Check logs:"
    echo "  sudo journalctl -u jellyfin -n 50"
    echo ""
    exit 1
fi

echo ""
echo "Step 2: Check Jellyfin web files"
echo "═══════════════════════════════════════════════════════════════"
echo ""

JELLYFIN_WEB="/usr/share/jellyfin/web"

if [ ! -d "$JELLYFIN_WEB" ]; then
    echo "❌ Jellyfin web directory not found: $JELLYFIN_WEB"
    echo ""
    echo "Is Jellyfin installed?"
    exit 1
fi

echo "✓ Jellyfin web directory exists: $JELLYFIN_WEB"
echo ""

# Check for our overlay files
echo "Step 3: Check if overlay files are present"
echo "═══════════════════════════════════════════════════════════════"
echo ""

OVERLAY_FILES=(
    "playback-progress-overlay.js"
    "playback-progress-overlay.css"
    "playback-progress-overlay-centered.css"
)

FOUND_OVERLAY=false

for file in "${OVERLAY_FILES[@]}"; do
    if [ -f "$JELLYFIN_WEB/$file" ]; then
        echo "✓ Found: $file"
        FOUND_OVERLAY=true
    fi
done

echo ""

if [ "$FOUND_OVERLAY" = false ]; then
    echo "ℹ️  No overlay files found - this is not the cause"
    echo ""
else
    echo "⚠️  Overlay files are present"
    echo ""
    echo "These MAY be causing JavaScript errors."
    echo ""
    echo "To test if overlay files are the problem:"
    echo "  1. Temporarily remove them:"
    echo "     sudo ./scripts/remove_overlay_files.sh"
    echo ""
    echo "  2. Clear browser cache (Ctrl+Shift+Delete)"
    echo ""
    echo "  3. Reload Jellyfin page"
    echo ""
    echo "  4. If it works, the overlay files had an issue"
    echo "     If still broken, it's a different problem"
    echo ""
fi

echo "Step 4: Check Jellyfin logs for errors"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "Recent Jellyfin errors:"
sudo journalctl -u jellyfin -n 50 --no-pager | grep -i "error\|exception\|fail" | tail -n 10

echo ""
echo ""

echo "Step 5: Check browser console"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Open your browser's developer console:"
echo "  • Chrome/Edge: Press F12 or Ctrl+Shift+I"
echo "  • Firefox: Press F12 or Ctrl+Shift+K"
echo "  • Safari: Enable Developer Menu, then press Cmd+Option+I"
echo ""
echo "Look for JavaScript errors (red text) in the Console tab."
echo ""
echo "Common errors to look for:"
echo "  • 'Uncaught ReferenceError'"
echo "  • 'Uncaught SyntaxError'"
echo "  • '404 Not Found' for .js or .css files"
echo "  • 'Failed to load resource'"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "QUICK FIXES TO TRY:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Fix 1: Clear browser cache"
echo "  Ctrl+Shift+Delete → Clear browsing data → Cached images and files"
echo ""
echo "Fix 2: Hard refresh the page"
echo "  Ctrl+Shift+R (or Cmd+Shift+R on Mac)"
echo ""
echo "Fix 3: Try a different browser"
echo "  See if the issue persists in another browser"
echo ""
echo "Fix 4: Temporarily remove overlay files (if installed)"
echo "  sudo ./scripts/remove_overlay_files.sh"
echo "  Then clear browser cache and reload"
echo ""
echo "Fix 5: Restart Jellyfin"
echo "  sudo systemctl restart jellyfin"
echo "  Wait 10 seconds, then try loading the page"
echo ""
echo "Fix 6: Check Jellyfin logs"
echo "  sudo journalctl -u jellyfin -f"
echo "  Look for errors when you try to load the page"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Please tell us:"
echo "  1. What error message do you see on the page?"
echo "  2. Does the page load at all or is it completely blank?"
echo "  3. Are there any JavaScript errors in browser console?"
echo "  4. Did this start after running install_all.sh?"
echo ""
