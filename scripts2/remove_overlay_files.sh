#!/bin/bash
#
# Temporarily remove overlay files to test if they're causing issues
#

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          REMOVE OVERLAY FILES (TROUBLESHOOTING)                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

JELLYFIN_WEB="/usr/share/jellyfin/web"
BACKUP_DIR="/tmp/jellyfin-overlay-backup-$(date +%Y%m%d-%H%M%S)"

if [ ! -d "$JELLYFIN_WEB" ]; then
    echo "❌ Jellyfin web directory not found: $JELLYFIN_WEB"
    exit 1
fi

echo "This will temporarily remove the overlay files to help troubleshoot."
echo "Files will be backed up to: $BACKUP_DIR"
echo ""

OVERLAY_FILES=(
    "playback-progress-overlay.js"
    "playback-progress-overlay.css"
    "playback-progress-overlay-centered.css"
)

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Removing overlay files..."
echo ""

REMOVED_COUNT=0

for file in "${OVERLAY_FILES[@]}"; do
    if [ -f "$JELLYFIN_WEB/$file" ]; then
        echo "  • Backing up and removing: $file"
        sudo cp "$JELLYFIN_WEB/$file" "$BACKUP_DIR/"
        sudo rm "$JELLYFIN_WEB/$file"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    else
        echo "  • Not found (skipping): $file"
    fi
done

echo ""

if [ $REMOVED_COUNT -eq 0 ]; then
    echo "ℹ️  No overlay files were found to remove"
    echo ""
    echo "The overlay files are NOT the cause of your issue."
    echo "Look for other causes (see troubleshooting guide)."
    rmdir "$BACKUP_DIR" 2>/dev/null
else
    echo "✓ Removed $REMOVED_COUNT overlay file(s)"
    echo "✓ Backup saved to: $BACKUP_DIR"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "NEXT STEPS:"
    echo ""
    echo "1. Clear your browser cache:"
    echo "   Ctrl+Shift+Delete → Clear cached images and files"
    echo ""
    echo "2. Hard refresh Jellyfin page:"
    echo "   Ctrl+Shift+R (or Cmd+Shift+R on Mac)"
    echo ""
    echo "3. Try loading Jellyfin again"
    echo ""
    echo "4. TEST RESULTS:"
    echo ""
    echo "   If Jellyfin WORKS now:"
    echo "     → The overlay files were the problem"
    echo "     → Report this issue"
    echo "     → We need to fix the overlay code"
    echo ""
    echo "   If Jellyfin STILL BROKEN:"
    echo "     → The overlay files are NOT the cause"
    echo "     → Restore them: sudo ./scripts/restore_overlay_files.sh"
    echo "     → Look for other causes"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "To restore overlay files later:"
    echo "  sudo ./scripts/restore_overlay_files.sh"
    echo ""
    echo "Backup location: $BACKUP_DIR"
    echo ""
fi
