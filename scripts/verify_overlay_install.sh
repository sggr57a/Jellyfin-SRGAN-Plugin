#!/bin/bash
# Verify that Jellyfin progress overlay files are installed

set -e

JELLYFIN_WEB_DIR="${JELLYFIN_WEB_DIR:-/usr/share/jellyfin/web}"

echo "========================================="
echo "Jellyfin Progress Overlay - Verification"
echo "========================================="
echo ""

# Check if Jellyfin web directory exists
if [[ ! -d "${JELLYFIN_WEB_DIR}" ]]; then
    echo "❌ Jellyfin web directory not found at: ${JELLYFIN_WEB_DIR}"
    echo ""
    echo "Possible locations:"
    echo "  - /usr/share/jellyfin/web"
    echo "  - /var/lib/jellyfin/web"
    echo "  - /opt/jellyfin/web"
    echo ""
    echo "Set JELLYFIN_WEB_DIR environment variable if different:"
    echo "  export JELLYFIN_WEB_DIR=/path/to/jellyfin/web"
    exit 1
fi

echo "✅ Jellyfin web directory found: ${JELLYFIN_WEB_DIR}"
echo ""

# Check CSS file
if [[ -f "${JELLYFIN_WEB_DIR}/playback-progress-overlay.css" ]]; then
    echo "✅ playback-progress-overlay.css is installed"
    SIZE=$(stat -f%z "${JELLYFIN_WEB_DIR}/playback-progress-overlay.css" 2>/dev/null || stat -c%s "${JELLYFIN_WEB_DIR}/playback-progress-overlay.css" 2>/dev/null)
    echo "   Size: ${SIZE} bytes"
else
    echo "❌ playback-progress-overlay.css is NOT installed"
    echo "   Expected: ${JELLYFIN_WEB_DIR}/playback-progress-overlay.css"
fi
echo ""

# Check JavaScript file
if [[ -f "${JELLYFIN_WEB_DIR}/playback-progress-overlay.js" ]]; then
    echo "✅ playback-progress-overlay.js is installed"
    SIZE=$(stat -f%z "${JELLYFIN_WEB_DIR}/playback-progress-overlay.js" 2>/dev/null || stat -c%s "${JELLYFIN_WEB_DIR}/playback-progress-overlay.js" 2>/dev/null)
    echo "   Size: ${SIZE} bytes"
else
    echo "❌ playback-progress-overlay.js is NOT installed"
    echo "   Expected: ${JELLYFIN_WEB_DIR}/playback-progress-overlay.js"
fi
echo ""

# Check optional centered CSS
if [[ -f "${JELLYFIN_WEB_DIR}/playback-progress-overlay-centered.css" ]]; then
    echo "✅ playback-progress-overlay-centered.css is installed (optional)"
    SIZE=$(stat -f%z "${JELLYFIN_WEB_DIR}/playback-progress-overlay-centered.css" 2>/dev/null || stat -c%s "${JELLYFIN_WEB_DIR}/playback-progress-overlay-centered.css" 2>/dev/null)
    echo "   Size: ${SIZE} bytes"
else
    echo "ℹ️  playback-progress-overlay-centered.css not installed (optional)"
fi
echo ""

# Check permissions
echo "Checking file permissions..."
if [[ -r "${JELLYFIN_WEB_DIR}/playback-progress-overlay.css" ]]; then
    echo "✅ CSS file is readable"
else
    echo "❌ CSS file is not readable - check permissions"
fi

if [[ -r "${JELLYFIN_WEB_DIR}/playback-progress-overlay.js" ]]; then
    echo "✅ JavaScript file is readable"
else
    echo "❌ JavaScript file is not readable - check permissions"
fi
echo ""

# Check if Jellyfin is running
echo "Checking Jellyfin status..."
if systemctl is-active --quiet jellyfin; then
    echo "✅ Jellyfin service is running"
    echo ""
    echo "Next steps:"
    echo "  1. Hard refresh browser: Ctrl+Shift+R"
    echo "  2. Play a video in Jellyfin"
    echo "  3. Look for progress overlay in top-right corner"
elif pgrep -f jellyfin >/dev/null; then
    echo "✅ Jellyfin process is running"
    echo ""
    echo "Next steps:"
    echo "  1. Hard refresh browser: Ctrl+Shift+R"
    echo "  2. Play a video in Jellyfin"
    echo "  3. Look for progress overlay in top-right corner"
else
    echo "⚠️  Jellyfin does not appear to be running"
    echo ""
    echo "Start Jellyfin:"
    echo "  sudo systemctl start jellyfin"
fi
echo ""

echo "========================================="
echo "Verification Complete"
echo "========================================="
echo ""

# Summary
ALL_OK=true
[[ ! -f "${JELLYFIN_WEB_DIR}/playback-progress-overlay.css" ]] && ALL_OK=false
[[ ! -f "${JELLYFIN_WEB_DIR}/playback-progress-overlay.js" ]] && ALL_OK=false

if $ALL_OK; then
    echo "✅ All required files are installed!"
    echo ""
    echo "To see the overlay:"
    echo "  1. Open Jellyfin in browser"
    echo "  2. Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)"
    echo "  3. Click play on any video"
    echo "  4. Look for overlay in top-right corner"
    echo ""
    echo "The overlay shows:"
    echo "  • Loading indicator (immediate)"
    echo "  • Progress percentage"
    echo "  • Processing speed"
    echo "  • ETA to completion"
    echo "  • Matches Jellyfin's theme automatically"
else
    echo "⚠️  Some files are missing"
    echo ""
    echo "To install manually:"
    echo "  sudo cp jellyfin-plugin/playback-progress-overlay.css ${JELLYFIN_WEB_DIR}/"
    echo "  sudo cp jellyfin-plugin/playback-progress-overlay.js ${JELLYFIN_WEB_DIR}/"
    echo ""
    echo "Or re-run installation:"
    echo "  bash scripts/install_all.sh"
fi
