#!/bin/bash
#
# Restore overlay files from backup or source
#

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          RESTORE OVERLAY FILES                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

JELLYFIN_WEB="/usr/share/jellyfin/web"
PLUGIN_DIR="jellyfin-plugin"

# Find most recent backup
LATEST_BACKUP=$(ls -dt /tmp/jellyfin-overlay-backup-* 2>/dev/null | head -n 1)

if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
    echo "Found backup: $LATEST_BACKUP"
    echo ""
    echo "Restoring from backup..."
    
    for file in "$LATEST_BACKUP"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "  • Restoring: $filename"
            sudo cp "$file" "$JELLYFIN_WEB/"
        fi
    done
    
    echo ""
    echo "✓ Restored overlay files from backup"
    
elif [ -d "$PLUGIN_DIR" ]; then
    echo "No backup found, restoring from source..."
    echo ""
    
    OVERLAY_FILES=(
        "playback-progress-overlay.js"
        "playback-progress-overlay.css"
        "playback-progress-overlay-centered.css"
    )
    
    for file in "${OVERLAY_FILES[@]}"; do
        if [ -f "$PLUGIN_DIR/$file" ]; then
            echo "  • Installing: $file"
            sudo cp "$PLUGIN_DIR/$file" "$JELLYFIN_WEB/"
        fi
    done
    
    echo ""
    echo "✓ Restored overlay files from source"
    
else
    echo "❌ Cannot restore overlay files"
    echo ""
    echo "No backup found and no source files available."
    echo ""
    echo "Re-run installation:"
    echo "  ./scripts/install_all.sh"
    echo ""
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Overlay files restored."
echo ""
echo "To take effect:"
echo "  1. Restart Jellyfin: sudo systemctl restart jellyfin"
echo "  2. Clear browser cache: Ctrl+Shift+Delete"
echo "  3. Reload Jellyfin page: Ctrl+Shift+R"
echo ""
