#!/bin/bash
#
# Diagnose and fix Jellyfin startup failures
#

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        JELLYFIN STARTUP FAILURE DIAGNOSTICS                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Error: 'Jellyfin Server has encountered an error and was not able to start.'"
echo ""

# Check service status
echo "Step 1: Check Jellyfin service status"
echo "═══════════════════════════════════════════════════════════════"
echo ""

sudo systemctl status jellyfin --no-pager -l

echo ""
echo ""

# Get recent error logs
echo "Step 2: Check Jellyfin error logs (last 50 lines)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "Looking for errors in logs..."
echo ""

sudo journalctl -u jellyfin -n 100 --no-pager | grep -i "error\|exception\|fail\|critical" | tail -n 20

echo ""
echo ""

echo "Step 3: Full recent logs (last 30 lines)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

sudo journalctl -u jellyfin -n 30 --no-pager

echo ""
echo ""

# Check file permissions
echo "Step 4: Check Jellyfin directories and permissions"
echo "═══════════════════════════════════════════════════════════════"
echo ""

JELLYFIN_DIRS=(
    "/var/lib/jellyfin"
    "/etc/jellyfin"
    "/var/log/jellyfin"
    "/usr/share/jellyfin"
    "/usr/share/jellyfin/web"
)

for dir in "${JELLYFIN_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        perms=$(stat -c "%a %U:%G" "$dir" 2>/dev/null || stat -f "%Lp %Su:%Sg" "$dir" 2>/dev/null)
        echo "✓ $dir"
        echo "  Permissions: $perms"
    else
        echo "❌ Missing: $dir"
    fi
done

echo ""
echo ""

# Check for our overlay files
echo "Step 5: Check if our overlay files could be the issue"
echo "═══════════════════════════════════════════════════════════════"
echo ""

JELLYFIN_WEB="/usr/share/jellyfin/web"
OVERLAY_FILES=(
    "playback-progress-overlay.js"
    "playback-progress-overlay.css"
    "playback-progress-overlay-centered.css"
)

FOUND_OVERLAY=false
for file in "${OVERLAY_FILES[@]}"; do
    if [ -f "$JELLYFIN_WEB/$file" ]; then
        perms=$(stat -c "%a %U:%G" "$JELLYFIN_WEB/$file" 2>/dev/null || stat -f "%Lp %Su:%Sg" "$JELLYFIN_WEB/$file" 2>/dev/null)
        echo "  $file: $perms"
        FOUND_OVERLAY=true
    fi
done

if [ "$FOUND_OVERLAY" = false ]; then
    echo "ℹ️  No overlay files found"
else
    echo ""
    echo "⚠️  Note: Overlay files are CLIENT-SIDE only (JS/CSS)"
    echo "   They should NOT prevent Jellyfin SERVER from starting."
    echo "   The startup failure is likely a different issue."
fi

echo ""
echo ""

# Check disk space
echo "Step 6: Check disk space"
echo "═══════════════════════════════════════════════════════════════"
echo ""

df -h / /var | head -n 1
df -h / /var | grep -v "Filesystem"

echo ""
echo ""

# Check for port conflicts
echo "Step 7: Check for port conflicts"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "Checking if port 8096 (Jellyfin default) is in use..."
PORT_CHECK=$(sudo netstat -tlnp 2>/dev/null | grep ":8096" || sudo lsof -i :8096 2>/dev/null)

if [ -n "$PORT_CHECK" ]; then
    echo "⚠️  Port 8096 is in use:"
    echo "$PORT_CHECK"
    echo ""
    echo "Another process is using Jellyfin's port!"
else
    echo "✓ Port 8096 is available"
fi

echo ""
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     COMMON SOLUTIONS                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "Solution 1: Fix permissions"
echo "───────────────────────────────────────────────────────────────"
echo "If permission errors were found above:"
echo ""
echo "  sudo chown -R jellyfin:jellyfin /var/lib/jellyfin"
echo "  sudo chown -R jellyfin:jellyfin /etc/jellyfin"
echo "  sudo chown -R jellyfin:jellyfin /var/log/jellyfin"
echo "  sudo systemctl restart jellyfin"
echo ""

echo "Solution 2: Check for database corruption"
echo "───────────────────────────────────────────────────────────────"
echo "If logs show database errors:"
echo ""
echo "  # Backup database"
echo "  sudo cp /var/lib/jellyfin/data/library.db /var/lib/jellyfin/data/library.db.backup"
echo ""
echo "  # Stop Jellyfin"
echo "  sudo systemctl stop jellyfin"
echo ""
echo "  # Try to repair database"
echo "  sudo -u jellyfin sqlite3 /var/lib/jellyfin/data/library.db 'PRAGMA integrity_check;'"
echo ""
echo "  # Start Jellyfin"
echo "  sudo systemctl start jellyfin"
echo ""

echo "Solution 3: Clear cache and temp files"
echo "───────────────────────────────────────────────────────────────"
echo "  sudo systemctl stop jellyfin"
echo "  sudo rm -rf /var/lib/jellyfin/cache/*"
echo "  sudo rm -rf /var/lib/jellyfin/transcodes/*"
echo "  sudo systemctl start jellyfin"
echo ""

echo "Solution 4: Reinstall Jellyfin"
echo "───────────────────────────────────────────────────────────────"
echo "If all else fails:"
echo ""
echo "  # Backup your data first!"
echo "  sudo cp -r /var/lib/jellyfin /var/lib/jellyfin.backup"
echo ""
echo "  # Reinstall Jellyfin"
echo "  sudo apt reinstall jellyfin  # Debian/Ubuntu"
echo "  # or"
echo "  sudo dnf reinstall jellyfin   # Fedora/RHEL"
echo ""

echo "Solution 5: Temporarily remove overlay files (unlikely to help)"
echo "───────────────────────────────────────────────────────────────"
echo "  sudo ./scripts/remove_overlay_files.sh"
echo "  sudo systemctl restart jellyfin"
echo ""
echo "  (But overlay files shouldn't prevent server startup)"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "IMMEDIATE ACTIONS:"
echo ""
echo "1. Review the logs above for specific error messages"
echo ""
echo "2. Look for keywords like:"
echo "   • 'permission denied'"
echo "   • 'database'"
echo "   • 'port already in use'"
echo "   • 'failed to bind'"
echo "   • 'exception'"
echo ""
echo "3. Try the most relevant solution above"
echo ""
echo "4. Get live logs:"
echo "   sudo journalctl -u jellyfin -f"
echo "   (Then try to start Jellyfin in another terminal)"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
