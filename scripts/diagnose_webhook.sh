#!/bin/bash
#
# Diagnose Webhook Plugin Installation
#

echo "=========================================================================="
echo "Webhook Plugin Diagnostic"
echo "=========================================================================="
echo ""

# Check plugins directory
echo "1. Checking /var/lib/jellyfin/plugins/ directory..."
if [ ! -d "/var/lib/jellyfin/plugins" ]; then
    echo "✗ Plugins directory not found!"
    exit 1
fi

echo "✓ Plugins directory exists"
echo ""

# List all plugins
echo "2. Installed plugins:"
ls -la /var/lib/jellyfin/plugins/ | grep -v "^total" | grep -v "^d.*\.$"
echo ""

# Look for webhook plugin
echo "3. Looking for Webhook plugin..."
WEBHOOK_DIRS=$(find /var/lib/jellyfin/plugins -maxdepth 1 -type d -name "Webhook_*" 2>/dev/null)

if [ -z "$WEBHOOK_DIRS" ]; then
    echo "✗ No Webhook plugin directory found (expected: Webhook_*)"
    echo ""
    echo "The webhook plugin needs to be installed first from Jellyfin:"
    echo "  1. Open Jellyfin Dashboard"
    echo "  2. Go to Plugins → Catalog"
    echo "  3. Search for 'Webhook'"
    echo "  4. Install the Webhook plugin"
    echo "  5. Restart Jellyfin"
    echo "  6. Then run install_all.sh to update it with Path support"
    exit 1
fi

echo "✓ Found webhook plugin directory:"
for dir in $WEBHOOK_DIRS; do
    echo "  - $dir"
done
echo ""

# Check each webhook directory
for WEBHOOK_DIR in $WEBHOOK_DIRS; do
    echo "4. Checking $WEBHOOK_DIR..."
    
    # Check for DLL
    if [ -f "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook.dll" ]; then
        DLL_SIZE=$(du -h "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook.dll" | cut -f1)
        DLL_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -c "%y" "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook.dll" 2>/dev/null | cut -d. -f1)
        echo "  ✓ DLL exists: $DLL_SIZE (modified: $DLL_DATE)"
    else
        echo "  ✗ DLL not found!"
    fi
    
    # List all files
    echo ""
    echo "  Files in directory:"
    ls -lh "$WEBHOOK_DIR/" | grep -v "^total" | awk '{print "    " $0}'
done
echo ""

# Check configuration
echo "5. Checking webhook configuration..."
WEBHOOK_CONFIG="/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"
if [ -f "$WEBHOOK_CONFIG" ]; then
    echo "✓ Configuration file exists"
    
    # Check for {{Path}} in template
    if grep -q "{{Path}}" "$WEBHOOK_CONFIG"; then
        echo "✓ {{Path}} variable found in configuration"
    else
        echo "✗ {{Path}} variable NOT in configuration"
        echo "  Run: sudo python3 scripts/configure_webhook.py http://localhost:5000 $WEBHOOK_CONFIG"
    fi
else
    echo "✗ Configuration file not found"
fi
echo ""

# Check build output
echo "6. Checking build output..."
WEBHOOK_BUILD_DIR="jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release"
if [ -d "$WEBHOOK_BUILD_DIR" ]; then
    echo "✓ Build directory exists: $WEBHOOK_BUILD_DIR"
    
    # Find net9.0 directory
    NET_DIR=$(find "$WEBHOOK_BUILD_DIR" -maxdepth 1 -type d -name "net*" | head -1)
    if [ -n "$NET_DIR" ]; then
        echo "✓ Framework directory: $NET_DIR"
        
        if [ -f "$NET_DIR/Jellyfin.Plugin.Webhook.dll" ]; then
            BUILD_SIZE=$(du -h "$NET_DIR/Jellyfin.Plugin.Webhook.dll" | cut -f1)
            BUILD_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$NET_DIR/Jellyfin.Plugin.Webhook.dll" 2>/dev/null || stat -c "%y" "$NET_DIR/Jellyfin.Plugin.Webhook.dll" 2>/dev/null | cut -d. -f1)
            echo "✓ Built DLL: $BUILD_SIZE (modified: $BUILD_DATE)"
        else
            echo "✗ Built DLL not found - need to build?"
        fi
    else
        echo "✗ No framework directory (net9.0) found"
    fi
else
    echo "✗ Build directory not found"
    echo "  Need to run build first?"
fi
echo ""

# Check source code
echo "7. Checking source code for Path patch..."
HELPERS_FILE="jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs"
if [ -f "$HELPERS_FILE" ]; then
    echo "✓ DataObjectHelpers.cs exists"
    
    if grep -q '"Path".*item\.Path' "$HELPERS_FILE"; then
        echo "✓ Path property IS patched in source"
        echo ""
        echo "  Implementation:"
        grep -A 3 -B 1 '"Path".*item\.Path' "$HELPERS_FILE" | sed 's/^/    /'
    else
        echo "✗ Path property NOT found in source"
        echo "  Run: ./scripts/patch_webhook_path.sh"
    fi
else
    echo "✗ Source file not found"
    echo "  Run: ./scripts/setup_webhook_source.sh"
fi
echo ""

# Check Jellyfin service
echo "8. Checking Jellyfin service..."
if systemctl is-active --quiet jellyfin; then
    echo "✓ Jellyfin service is running"
else
    echo "✗ Jellyfin service is not running"
    echo "  Run: sudo systemctl start jellyfin"
fi
echo ""

echo "=========================================================================="
echo "Summary & Next Steps"
echo "=========================================================================="
echo ""

# Determine what needs to be done
NEEDS_CATALOG_INSTALL=false
NEEDS_SOURCE=false
NEEDS_PATCH=false
NEEDS_BUILD=false
NEEDS_INSTALL=false

if [ -z "$WEBHOOK_DIRS" ]; then
    NEEDS_CATALOG_INSTALL=true
fi

if [ ! -f "$HELPERS_FILE" ]; then
    NEEDS_SOURCE=true
elif ! grep -q '"Path".*item\.Path' "$HELPERS_FILE"; then
    NEEDS_PATCH=true
fi

if [ -z "$NET_DIR" ] || [ ! -f "$NET_DIR/Jellyfin.Plugin.Webhook.dll" ]; then
    NEEDS_BUILD=true
fi

if $NEEDS_CATALOG_INSTALL; then
    echo "❌ Webhook plugin not installed from catalog"
    echo ""
    echo "ACTION REQUIRED:"
    echo "1. Open Jellyfin Dashboard → Plugins → Catalog"
    echo "2. Search for 'Webhook' and install it"
    echo "3. Restart Jellyfin"
    echo "4. Then run: sudo ./scripts/install_all.sh"
elif $NEEDS_SOURCE; then
    echo "❌ Webhook source code missing"
    echo ""
    echo "ACTION REQUIRED:"
    echo "  ./scripts/setup_webhook_source.sh"
elif $NEEDS_PATCH; then
    echo "❌ Path patch not applied"
    echo ""
    echo "ACTION REQUIRED:"
    echo "  ./scripts/patch_webhook_path.sh"
    echo "  sudo ./scripts/install_all.sh"
elif $NEEDS_BUILD; then
    echo "❌ Webhook not built"
    echo ""
    echo "ACTION REQUIRED:"
    echo "  sudo ./scripts/install_all.sh"
else
    echo "✅ Everything looks good!"
    echo ""
    echo "Test the webhook:"
    echo "1. tail -f /var/log/srgan-watchdog.log"
    echo "2. Play a video in Jellyfin"
    echo "3. Check logs for: \"Path\": \"/path/to/video.mkv\""
fi

echo ""
