#!/bin/bash
# Build script for modified Jellyfin Webhook Plugin with Path support

set -e  # Exit on error

echo "=========================================="
echo "Jellyfin Webhook Plugin Builder"
echo "=========================================="
echo ""

# Change to plugin directory
cd "$(dirname "$0")"

# Check for dotnet
if command -v dotnet &> /dev/null; then
    echo "✓ Found dotnet: $(dotnet --version)"
    echo ""
    
    echo "Building plugin with dotnet..."
    cd Jellyfin.Plugin.Webhook
    dotnet build -c Release
    
    echo ""
    echo "=========================================="
    echo "✓ Build complete!"
    echo "=========================================="
    echo ""
    echo "Plugin DLL location:"
    echo "  $(pwd)/bin/Release/net9.0/Jellyfin.Plugin.Webhook.dll"
    echo ""
    echo "To deploy to Jellyfin:"
    echo ""
    echo "  # For Linux (bare metal):"
    echo "  sudo systemctl stop jellyfin"
    echo "  sudo mkdir -p /var/lib/jellyfin/plugins/Webhook"
    echo "  sudo cp bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/Webhook/"
    echo "  sudo systemctl start jellyfin"
    echo ""
    echo "  # For Docker:"
    echo "  docker stop jellyfin"
    echo "  docker cp bin/Release/net9.0/. jellyfin:/config/plugins/Webhook/"
    echo "  docker start jellyfin"
    echo ""
    
else
    echo "✗ dotnet not found in PATH"
    echo ""
    echo "Choose an installation method:"
    echo ""
    echo "Option 1: Install .NET 9.0 SDK"
    echo "  macOS: brew install dotnet@9"
    echo "  Linux: https://dotnet.microsoft.com/download/dotnet/9.0"
    echo ""
    echo "Option 2: Build with Docker (no .NET SDK required)"
    echo ""
    read -p "Build with Docker? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Building with Docker..."
        docker run --rm \
            -v "$(pwd):/src" \
            -w /src/Jellyfin.Plugin.Webhook \
            mcr.microsoft.com/dotnet/sdk:9.0 \
            dotnet build -c Release
        
        echo ""
        echo "=========================================="
        echo "✓ Build complete!"
        echo "=========================================="
        echo ""
        echo "Plugin DLL location:"
        echo "  $(pwd)/Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.dll"
        echo ""
    else
        echo ""
        echo "Build cancelled. Please install .NET SDK or use Docker."
        exit 1
    fi
fi

echo "Next steps:"
echo "1. Deploy the plugin to Jellyfin (see commands above)"
echo "2. Restart Jellyfin"
echo "3. Configure webhook with {{Path}} template variable"
echo "4. Test by playing a video"
echo ""
