#!/bin/bash
#
# Fix Jellyfin stuck on "Initializing network settings"
#

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   JELLYFIN STUCK ON 'INITIALIZING NETWORK SETTINGS'           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "Diagnosing why Jellyfin won't progress past network initialization..."
echo ""

# Step 1: Check if service is actually running
echo "Step 1: Check Jellyfin service status"
echo "═══════════════════════════════════════════════════════════════"
echo ""

sudo systemctl status jellyfin --no-pager -l | head -n 15

echo ""

# Step 2: Check recent logs for stuck point
echo "Step 2: Check what Jellyfin is doing (last 20 lines)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

sudo journalctl -u jellyfin -n 20 --no-pager

echo ""
echo ""

# Step 3: Check for network.xml corruption
echo "Step 3: Check network configuration file"
echo "═══════════════════════════════════════════════════════════════"
echo ""

NETWORK_XML="/etc/jellyfin/network.xml"

if [ -f "$NETWORK_XML" ]; then
    echo "Network config exists: $NETWORK_XML"
    echo ""
    echo "Contents:"
    sudo cat "$NETWORK_XML"
    echo ""
    
    # Check if it's valid XML
    if command -v xmllint &> /dev/null; then
        echo "Validating XML..."
        if sudo xmllint --noout "$NETWORK_XML" 2>&1; then
            echo "✓ XML is valid"
        else
            echo "❌ XML is INVALID or corrupted!"
            echo ""
            echo "This could be why Jellyfin is stuck."
        fi
    fi
else
    echo "⚠️  Network config not found: $NETWORK_XML"
    echo "   This is OK - Jellyfin will create defaults"
fi

echo ""
echo ""

# Step 4: Check port availability
echo "Step 4: Check if port 8096 is available"
echo "═══════════════════════════════════════════════════════════════"
echo ""

PORT_CHECK=$(sudo lsof -i :8096 2>/dev/null || sudo netstat -tlnp 2>/dev/null | grep ":8096")

if [ -n "$PORT_CHECK" ]; then
    echo "Port 8096 status:"
    echo "$PORT_CHECK"
    echo ""
    
    if echo "$PORT_CHECK" | grep -q "jellyfin"; then
        echo "✓ Jellyfin is listening on port 8096"
        echo "  (But web interface not responding)"
    else
        echo "❌ Another process is using port 8096!"
        echo "   This prevents Jellyfin from starting properly"
    fi
else
    echo "❌ Port 8096 is NOT being used"
    echo "   Jellyfin hasn't bound to the port yet"
    echo "   It's stuck before reaching that point"
fi

echo ""
echo ""

# Step 5: Check for errors in logs
echo "Step 5: Check for errors in logs"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "Recent errors:"
sudo journalctl -u jellyfin -n 100 --no-pager | grep -i "error\|exception\|fail\|timeout" | tail -n 10

echo ""
echo ""

# Step 6: Check system resources
echo "Step 6: Check system resources"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "Disk space:"
df -h / /var | grep -v "Filesystem"

echo ""
echo "Memory:"
free -h | grep "Mem:"

echo ""
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                          SOLUTIONS                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "Solution 1: Reset network configuration"
echo "───────────────────────────────────────────────────────────────"
echo "If network.xml is corrupted or has bad settings:"
echo ""
echo "  sudo systemctl stop jellyfin"
echo "  sudo mv /etc/jellyfin/network.xml /etc/jellyfin/network.xml.backup"
echo "  sudo systemctl start jellyfin"
echo ""
echo "Jellyfin will recreate network.xml with defaults."
echo ""

echo "Solution 2: Kill and restart Jellyfin"
echo "───────────────────────────────────────────────────────────────"
echo "If Jellyfin process is hung:"
echo ""
echo "  sudo systemctl stop jellyfin"
echo "  sudo pkill -9 jellyfin"
echo "  sleep 2"
echo "  sudo systemctl start jellyfin"
echo ""

echo "Solution 3: Check for port conflict"
echo "───────────────────────────────────────────────────────────────"
echo "If another process is using port 8096:"
echo ""
echo "  # Find the process"
echo "  sudo lsof -i :8096"
echo ""
echo "  # Kill it (replace PID with actual process ID)"
echo "  sudo kill <PID>"
echo ""
echo "  # Restart Jellyfin"
echo "  sudo systemctl restart jellyfin"
echo ""

echo "Solution 4: Clear all Jellyfin data (NUCLEAR OPTION)"
echo "───────────────────────────────────────────────────────────────"
echo "⚠️  WARNING: This will reset ALL Jellyfin settings!"
echo "Only use if nothing else works and you have backups."
echo ""
echo "  sudo systemctl stop jellyfin"
echo "  sudo mv /etc/jellyfin /etc/jellyfin.backup"
echo "  sudo rm -rf /var/lib/jellyfin/cache/*"
echo "  sudo systemctl start jellyfin"
echo ""

echo "Solution 5: Increase timeout and watch startup"
echo "───────────────────────────────────────────────────────────────"
echo "Sometimes it just needs more time (especially first boot):"
echo ""
echo "  # Restart Jellyfin"
echo "  sudo systemctl restart jellyfin"
echo ""
echo "  # Watch logs in real-time"
echo "  sudo journalctl -u jellyfin -f"
echo ""
echo "  # Wait 2-3 minutes"
echo "  # Look for 'Kestrel listening' or 'Startup complete'"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "RECOMMENDED ACTION:"
echo ""
echo "Based on what you see above, try these in order:"
echo ""
echo "1. If you see XML errors → Solution 1 (reset network.xml)"
echo "2. If no port binding → Solution 2 (kill and restart)"
echo "3. If port conflict → Solution 3 (kill conflicting process)"
echo "4. If nothing helps → Solution 5 (wait longer with logs)"
echo "5. Last resort → Solution 4 (nuclear reset)"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
