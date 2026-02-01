#!/bin/bash
# Build script for RealTimeHDRSRGAN Jellyfin Plugin

set -e  # Exit on error

echo "=========================================="
echo "RealTimeHDRSRGAN Plugin Builder"
echo "=========================================="
echo ""

# Change to plugin directory
cd "$(dirname "$0")/Server"

# Check for dotnet
if command -v dotnet &> /dev/null; then
    echo "✓ Found dotnet: $(dotnet --version)"
    echo ""
    
    echo "Cleaning previous builds..."
    dotnet clean -c Release
    
    echo ""
    echo "Building plugin with dotnet..."
    dotnet build -c Release
    
    echo ""
    echo "=========================================="
    echo "✓ Build complete!"
    echo "=========================================="
    echo ""
    echo "Plugin DLL location:"
    echo "  $(pwd)/bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll"
    echo ""
    echo "To deploy to Jellyfin:"
    echo ""
    echo "  # For Linux (bare metal):"
    echo "  sudo systemctl stop jellyfin"
    echo "  sudo mkdir -p /var/lib/jellyfin/plugins/RealTimeHDRSRGAN"
    echo "  sudo cp bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/"
    echo "  sudo cp bin/Release/net9.0/*.sh /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/ 2>/dev/null || true"
    echo "  sudo chmod +x /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/*.sh 2>/dev/null || true"
    echo "  sudo systemctl start jellyfin"
    echo ""
    echo "  # For Docker:"
    echo "  docker stop jellyfin"
    echo "  docker cp bin/Release/net9.0/. jellyfin:/config/plugins/RealTimeHDRSRGAN/"
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
            -w /src \
            mcr.microsoft.com/dotnet/sdk:9.0 \
            sh -c "dotnet clean -c Release && dotnet build -c Release"
        
        echo ""
        echo "=========================================="
        echo "✓ Build complete!"
        echo "=========================================="
        echo ""
        echo "Plugin DLL location:"
        echo "  $(pwd)/bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll"
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
echo "3. Check Dashboard → Plugins to verify it loaded"
echo "4. Configure the plugin settings"
echo ""
