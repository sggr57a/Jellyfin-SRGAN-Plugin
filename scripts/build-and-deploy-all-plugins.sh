#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
SRGAN_DIR="$PROJECT_ROOT/jellyfin-plugin/Server"
WEBHOOK_DIR="$PROJECT_ROOT/jellyfin-plugin-webhook"

echo "=========================================="
echo "Jellyfin Plugin Builder and Deployer"
echo "=========================================="
echo ""

# Check for dotnet SDK
if ! command -v dotnet &> /dev/null; then
    echo "❌ ERROR: dotnet SDK not found"
    echo ""
    echo "Install .NET 9.0 SDK:"
    echo "  Ubuntu/Debian: sudo apt install -y dotnet-sdk-9.0"
    echo "  Or download: https://dotnet.microsoft.com/download"
    exit 1
fi

echo "✓ Found dotnet SDK: $(dotnet --version)"
echo ""

# ===========================================
# BUILD SRGAN PLUGIN
# ===========================================
echo "=========================================="
echo "Building SRGAN Plugin..."
echo "=========================================="

cd "$SRGAN_DIR"
dotnet clean > /dev/null 2>&1 || true
dotnet build -c Release

if [ ! -f "bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll" ]; then
    echo "❌ ERROR: SRGAN plugin build failed - DLL not found"
    exit 1
fi

echo "✓ SRGAN plugin built successfully"
echo "  Location: $SRGAN_DIR/bin/Release/net9.0/"
echo ""

# Verify helper scripts are present
if [ ! -f "bin/Release/net9.0/gpu-detection.sh" ]; then
    echo "⚠ WARNING: gpu-detection.sh not copied to output"
fi

# ===========================================
# BUILD WEBHOOK PLUGIN
# ===========================================
echo "=========================================="
echo "Building Webhook Plugin..."
echo "=========================================="

cd "$WEBHOOK_DIR"
dotnet clean > /dev/null 2>&1 || true
dotnet build -c Release

if [ ! -f "Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.dll" ]; then
    echo "❌ ERROR: Webhook plugin build failed - DLL not found"
    exit 1
fi

echo "✓ Webhook plugin built successfully"
echo "  Location: $WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/"

# Verify deps.json exists
if [ -f "Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.deps.json" ]; then
    echo "✓ deps.json generated"
else
    echo "⚠ WARNING: deps.json not found (might cause issues)"
fi

echo ""

# ===========================================
# FIND JELLYFIN PLUGIN DIRECTORIES
# ===========================================
echo "=========================================="
echo "Finding Jellyfin Plugin Directories..."
echo "=========================================="

JELLYFIN_PLUGINS_DIR=""
SRGAN_PLUGIN_DIR=""
WEBHOOK_PLUGIN_DIR=""
INSTALL_METHOD=""

# Check for standard Linux installation
if [ -d "/var/lib/jellyfin/plugins" ]; then
    JELLYFIN_PLUGINS_DIR="/var/lib/jellyfin/plugins"
    SRGAN_PLUGIN_DIR=$(find "$JELLYFIN_PLUGINS_DIR" -type d -name "Real-Time*HDR*SRGAN*" | head -1)
    WEBHOOK_PLUGIN_DIR=$(find "$JELLYFIN_PLUGINS_DIR" -type d -name "Webhook_*" | head -1)
    INSTALL_METHOD="bare-metal"
    echo "✓ Found Jellyfin plugins directory: $JELLYFIN_PLUGINS_DIR"
# Check for Docker container
elif docker ps --format '{{.Names}}' 2>/dev/null | grep -q jellyfin; then
    INSTALL_METHOD="docker"
    echo "✓ Found Docker container: jellyfin"
    SRGAN_PLUGIN_DIR=$(docker exec jellyfin find /config/plugins -type d -name "Real-Time*HDR*SRGAN*" 2>/dev/null | head -1 || echo "")
    WEBHOOK_PLUGIN_DIR=$(docker exec jellyfin find /config/plugins -type d -name "Webhook_*" 2>/dev/null | head -1 || echo "")
else
    echo "⚠ Could not auto-detect Jellyfin installation"
    INSTALL_METHOD="manual"
fi

echo ""

# ===========================================
# INSTALL PLUGINS
# ===========================================
if [ "$INSTALL_METHOD" = "bare-metal" ]; then
    echo "=========================================="
    echo "Installing Plugins (Bare Metal)"
    echo "=========================================="
    
    # Install SRGAN Plugin
    if [ -z "$SRGAN_PLUGIN_DIR" ]; then
        echo "⚠ SRGAN plugin directory not found - first time install?"
        echo "Creating directory..."
        SRGAN_PLUGIN_DIR="$JELLYFIN_PLUGINS_DIR/Real-Time HDR SRGAN Pipeline_1.0.0.0"
        sudo mkdir -p "$SRGAN_PLUGIN_DIR"
    fi
    
    echo "Installing SRGAN plugin to: $SRGAN_PLUGIN_DIR"
    
    # Backup if exists
    if [ -f "$SRGAN_PLUGIN_DIR/Jellyfin.Plugin.RealTimeHdrSrgan.dll" ]; then
        sudo cp "$SRGAN_PLUGIN_DIR/Jellyfin.Plugin.RealTimeHdrSrgan.dll" \
                "$SRGAN_PLUGIN_DIR/Jellyfin.Plugin.RealTimeHdrSrgan.dll.backup"
        echo "  ✓ Backed up existing DLL"
    fi
    
    # Copy files
    sudo cp "$SRGAN_DIR/bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll" "$SRGAN_PLUGIN_DIR/"
    sudo cp "$SRGAN_DIR/bin/Release/net9.0/"*.sh "$SRGAN_PLUGIN_DIR/" 2>/dev/null || true
    sudo chmod +x "$SRGAN_PLUGIN_DIR/"*.sh 2>/dev/null || true
    echo "  ✓ SRGAN plugin installed"
    
    # Install Webhook Plugin
    if [ -z "$WEBHOOK_PLUGIN_DIR" ]; then
        echo ""
        echo "❌ ERROR: Webhook plugin directory not found"
        echo "Install the webhook plugin from Jellyfin dashboard first, then run this script again"
        exit 1
    fi
    
    echo ""
    echo "Installing Webhook plugin to: $WEBHOOK_PLUGIN_DIR"
    
    # Backup if exists
    if [ -f "$WEBHOOK_PLUGIN_DIR/Jellyfin.Plugin.Webhook.dll" ]; then
        sudo cp "$WEBHOOK_PLUGIN_DIR/Jellyfin.Plugin.Webhook.dll" \
                "$WEBHOOK_PLUGIN_DIR/Jellyfin.Plugin.Webhook.dll.backup"
        echo "  ✓ Backed up existing DLL"
    fi
    
    # Copy ALL files (DLL + dependencies + deps.json)
    echo "  Copying plugin files..."
    sudo cp -f "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/"*.dll "$WEBHOOK_PLUGIN_DIR/"
    
    if [ -f "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.deps.json" ]; then
        sudo cp -f "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.deps.json" "$WEBHOOK_PLUGIN_DIR/"
        echo "  ✓ deps.json copied"
    fi
    
    echo "  ✓ Webhook plugin installed"
    
    # Restart Jellyfin
    echo ""
    echo "=========================================="
    echo "Restarting Jellyfin..."
    echo "=========================================="
    
    sudo systemctl restart jellyfin
    echo "✓ Jellyfin restarted"
    
    echo ""
    echo "Waiting 10 seconds for Jellyfin to initialize..."
    sleep 10
    
    if systemctl is-active --quiet jellyfin; then
        echo "✓ Jellyfin is running"
    else
        echo "❌ ERROR: Jellyfin failed to start"
        echo ""
        echo "Check logs:"
        echo "  sudo journalctl -u jellyfin -n 50 --no-pager"
        exit 1
    fi

elif [ "$INSTALL_METHOD" = "docker" ]; then
    echo "=========================================="
    echo "Installing Plugins (Docker)"
    echo "=========================================="
    
    # Install SRGAN Plugin
    if [ -z "$SRGAN_PLUGIN_DIR" ]; then
        echo "⚠ SRGAN plugin directory not found - creating..."
        SRGAN_PLUGIN_DIR="/config/plugins/Real-Time HDR SRGAN Pipeline_1.0.0.0"
        docker exec jellyfin mkdir -p "$SRGAN_PLUGIN_DIR"
    fi
    
    echo "Installing SRGAN plugin to: $SRGAN_PLUGIN_DIR"
    docker cp "$SRGAN_DIR/bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll" "jellyfin:$SRGAN_PLUGIN_DIR/"
    docker cp "$SRGAN_DIR/bin/Release/net9.0/gpu-detection.sh" "jellyfin:$SRGAN_PLUGIN_DIR/" 2>/dev/null || true
    docker cp "$SRGAN_DIR/bin/Release/net9.0/backup-config.sh" "jellyfin:$SRGAN_PLUGIN_DIR/" 2>/dev/null || true
    docker cp "$SRGAN_DIR/bin/Release/net9.0/restore-config.sh" "jellyfin:$SRGAN_PLUGIN_DIR/" 2>/dev/null || true
    docker exec jellyfin chmod +x "$SRGAN_PLUGIN_DIR/"*.sh 2>/dev/null || true
    echo "  ✓ SRGAN plugin installed"
    
    # Install Webhook Plugin
    if [ -z "$WEBHOOK_PLUGIN_DIR" ]; then
        echo ""
        echo "❌ ERROR: Webhook plugin directory not found in Docker container"
        echo "Install the webhook plugin from Jellyfin dashboard first"
        exit 1
    fi
    
    echo ""
    echo "Installing Webhook plugin to: $WEBHOOK_PLUGIN_DIR"
    
    # Copy all DLLs
    for dll in "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/"*.dll; do
        [ -f "$dll" ] && docker cp "$dll" "jellyfin:$WEBHOOK_PLUGIN_DIR/"
    done
    
    if [ -f "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.deps.json" ]; then
        docker cp "$WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.deps.json" \
                  "jellyfin:$WEBHOOK_PLUGIN_DIR/"
        echo "  ✓ deps.json copied"
    fi
    
    echo "  ✓ Webhook plugin installed"
    
    # Restart container
    echo ""
    echo "=========================================="
    echo "Restarting Docker Container..."
    echo "=========================================="
    
    docker restart jellyfin
    echo "✓ Container restarted"
    
    echo ""
    echo "Waiting 10 seconds for Jellyfin to initialize..."
    sleep 10
    
    if docker ps | grep -q jellyfin; then
        echo "✓ Container is running"
    else
        echo "❌ ERROR: Container failed to start"
        echo ""
        echo "Check logs:"
        echo "  docker logs jellyfin --tail 50"
        exit 1
    fi

else
    # Manual installation instructions
    echo "=========================================="
    echo "Manual Installation Required"
    echo "=========================================="
    echo ""
    echo "Built artifacts are ready at:"
    echo "  SRGAN:   $SRGAN_DIR/bin/Release/net9.0/"
    echo "  Webhook: $WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/"
    echo ""
    echo "Manual steps:"
    echo ""
    echo "1. Find your Jellyfin plugin directories:"
    echo "   find /var/lib/jellyfin/plugins -type d -name 'Real-Time*' -o -name 'Webhook_*'"
    echo ""
    echo "2. Copy SRGAN plugin:"
    echo "   sudo cp $SRGAN_DIR/bin/Release/net9.0/*.dll /path/to/Real-Time*/"
    echo "   sudo cp $SRGAN_DIR/bin/Release/net9.0/*.sh /path/to/Real-Time*/"
    echo ""
    echo "3. Copy Webhook plugin (ALL files):"
    echo "   sudo cp $WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/*.dll /path/to/Webhook_*/"
    echo "   sudo cp $WEBHOOK_DIR/Jellyfin.Plugin.Webhook/bin/Release/net9.0/*.deps.json /path/to/Webhook_*/"
    echo ""
    echo "4. Restart Jellyfin:"
    echo "   sudo systemctl restart jellyfin"
    exit 0
fi

# ===========================================
# VERIFICATION
# ===========================================
echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="

if [ "$INSTALL_METHOD" = "bare-metal" ]; then
    echo "Installed files in $SRGAN_PLUGIN_DIR:"
    ls -lh "$SRGAN_PLUGIN_DIR/" | grep -E '\.(dll|sh)$'
    
    echo ""
    echo "Installed files in $WEBHOOK_PLUGIN_DIR:"
    ls -lh "$WEBHOOK_PLUGIN_DIR/" | grep -E '\.(dll|json)$' | head -10
    
    echo ""
    echo "Check Jellyfin logs:"
    echo "  sudo journalctl -u jellyfin -n 30 --no-pager | grep -i plugin"
    sudo journalctl -u jellyfin -n 30 --no-pager | grep -i "plugin\|error" || echo "  (No recent plugin logs)"
    
elif [ "$INSTALL_METHOD" = "docker" ]; then
    echo "Check Docker logs:"
    echo "  docker logs jellyfin --tail 30 | grep -i plugin"
    docker logs jellyfin --tail 30 2>&1 | grep -i "plugin\|error" || echo "  (No recent plugin logs)"
fi

echo ""
echo "=========================================="
echo "✓ Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Open Jellyfin Dashboard → Plugins"
echo "2. Verify 'Real-Time HDR SRGAN Pipeline' is loaded"
echo "3. Verify 'Webhook' is loaded"
echo "4. Configure webhook with your template"
echo "5. Play a movie and check if Path variable appears in webhook"
echo ""
echo "Enable debug logging (optional):"
echo "  Edit /etc/jellyfin/logging.json and add:"
echo "    \"Jellyfin.Plugin.Webhook\": \"Debug\","
echo "    \"Jellyfin.Plugin.RealTimeHdrSrgan\": \"Debug\""
echo ""


exit 0
