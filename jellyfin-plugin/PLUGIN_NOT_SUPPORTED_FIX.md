# RealTimeHDRSRGAN Plugin - "Not Supported" Fix

## Problem

Jellyfin reports that the RealTimeHDRSRGAN plugin is "not supported" even though all files are present.

## Root Causes Identified & Fixed

### ✅ Issue 1: Target ABI Mismatch (FIXED)
**Problem**: Plugin was targeting Jellyfin 10.8.0.0, but you're likely running Jellyfin 10.11+
**Fixed in**:
- `manifest.json` - Updated `targetAbi` from "10.8.0.0" to "10.11.0.0"
- `build.yaml` - Updated `targetAbi` from "10.8.0.0" to "10.11.0.0"

### ✅ Issue 2: Incorrect Package References (FIXED)
**Problem**: Plugin was using local DLL references instead of NuGet packages
**Fixed in**:
- `Server/RealTimeHdrSrgan.Plugin.csproj` - Changed from local `<Reference>` to `<PackageReference Include="Jellyfin.Controller" Version="10.11.*" />`

### ❌ Issue 3: Plugin Not Built (NEEDS ACTION)
**Problem**: The plugin source code has never been compiled into a DLL
**Solution**: Use the build script created below

## Build Instructions

### Quick Build (Using Docker - Recommended)

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin

# Build with Docker (no .NET SDK needed)
docker run --rm \
  -v "$(pwd)/Server:/src" \
  -w /src \
  mcr.microsoft.com/dotnet/sdk:9.0 \
  sh -c "dotnet clean -c Release && dotnet build -c Release"

# Verify build succeeded
ls -la Server/bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll
```

### Using Build Script

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin
./build-plugin.sh
```

The script will:
1. Check if dotnet is installed
2. If not, offer to build with Docker
3. Provide deployment instructions

### Manual Build (If .NET SDK is Installed)

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin/Server
dotnet clean -c Release
dotnet build -c Release
```

## Deployment Instructions

After building, deploy the plugin to Jellyfin:

### For Linux (Bare Metal)

```bash
# Stop Jellyfin
sudo systemctl stop jellyfin

# Create plugin directory
sudo mkdir -p /var/lib/jellyfin/plugins/RealTimeHDRSRGAN

# Copy all DLLs
sudo cp jellyfin-plugin/Server/bin/Release/net9.0/*.dll \
  /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/

# Copy shell scripts
sudo cp jellyfin-plugin/Server/bin/Release/net9.0/*.sh \
  /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/ 2>/dev/null || true

# Make scripts executable
sudo chmod +x /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/*.sh 2>/dev/null || true

# Set ownership
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/RealTimeHDRSRGAN

# Start Jellyfin
sudo systemctl start jellyfin
```

### For Docker

```bash
# Stop Jellyfin container
docker stop jellyfin

# Copy plugin files
docker cp jellyfin-plugin/Server/bin/Release/net9.0/. \
  jellyfin:/config/plugins/RealTimeHDRSRGAN/

# Make scripts executable inside container
docker exec jellyfin chmod +x /config/plugins/RealTimeHDRSRGAN/*.sh 2>/dev/null || true

# Start Jellyfin container
docker start jellyfin
```

### For macOS (Bare Metal)

```bash
# Stop Jellyfin
brew services stop jellyfin

# Create plugin directory
mkdir -p ~/Library/Application\ Support/jellyfin/plugins/RealTimeHDRSRGAN

# Copy plugin files
cp jellyfin-plugin/Server/bin/Release/net9.0/*.dll \
  ~/Library/Application\ Support/jellyfin/plugins/RealTimeHDRSRGAN/

# Copy shell scripts
cp jellyfin-plugin/Server/bin/Release/net9.0/*.sh \
  ~/Library/Application\ Support/jellyfin/plugins/RealTimeHDRSRGAN/ 2>/dev/null || true

# Make scripts executable
chmod +x ~/Library/Application\ Support/jellyfin/plugins/RealTimeHDRSRGAN/*.sh 2>/dev/null || true

# Start Jellyfin
brew services start jellyfin
```

## Verification Steps

### 1. Check Plugin is Recognized

After restarting Jellyfin:

1. Open Jellyfin web interface (http://localhost:8096)
2. Go to **Dashboard** → **Plugins**
3. Look for **"Real-Time HDR SRGAN Pipeline"**
4. It should show version 1.0.0 and status "Active"

### 2. Check Jellyfin Logs

If the plugin doesn't appear:

```bash
# Docker
docker logs jellyfin | grep -i "realtimehdr"

# Linux systemd
sudo journalctl -u jellyfin | grep -i "realtimehdr"

# Log files
tail -f /var/log/jellyfin/log_*.txt | grep -i plugin
```

Look for errors like:
- "Target ABI not supported"
- "Failed to load plugin"
- "Missing dependencies"

### 3. Test Plugin Configuration

1. Dashboard → Plugins → Real-Time HDR SRGAN Pipeline
2. Click on the plugin name
3. You should see the configuration page with:
   - Enable Upscaling toggle
   - GPU Device selection
   - Upscale Factor (2x or 4x)
   - HLS Streaming options
   - Watchdog URL

### 4. Test API Endpoints

```bash
# Test GPU detection endpoint
curl -X POST http://localhost:8096/Plugins/RealTimeHDRSRGAN/DetectGPU

# Test configuration endpoint
curl http://localhost:8096/Plugins/RealTimeHDRSRGAN/Configuration
```

## Files Modified

1. **jellyfin-plugin/manifest.json**
   - Updated `targetAbi` to "10.11.0.0"

2. **jellyfin-plugin/build.yaml**
   - Updated `targetAbi` to "10.11.0.0"

3. **jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj**
   - Replaced local DLL references with NuGet package reference
   - Now uses `Jellyfin.Controller` package version 10.11.*

4. **jellyfin-plugin/build-plugin.sh** (NEW)
   - Automated build script with Docker fallback

## Common Issues & Solutions

### Issue: "Plugin requires a higher Jellyfin version"
**Cause**: Your Jellyfin is older than 10.11
**Solution**: Either upgrade Jellyfin or change targetAbi back to match your version

### Issue: "Unable to load plugin assembly"
**Cause**: Missing dependencies or wrong .NET version
**Solution**: Make sure all DLLs are copied, including dependencies

### Issue: "Plugin crashes on load"
**Check**:
1. Jellyfin logs for stack trace
2. All dependencies are in the plugin folder
3. .NET runtime version matches (should be 9.0)

### Issue: Scripts not working (GPU detection, backup, etc.)
**Cause**: Scripts not executable or not copied
**Solution**:
```bash
# Make scripts executable
sudo chmod +x /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/*.sh
```

### Issue: "Jellyfin.Controller not found"
**Cause**: NuGet package not restored during build
**Solution**:
```bash
cd jellyfin-plugin/Server
dotnet restore
dotnet build -c Release
```

## What the Plugin Does

Once loaded successfully, the plugin provides:

1. **Configuration Page**: Web UI for configuring upscaling settings
2. **API Endpoints**:
   - `/Plugins/RealTimeHDRSRGAN/DetectGPU` - Detect NVIDIA GPUs
   - `/Plugins/RealTimeHDRSRGAN/Configuration` - Get/Set configuration
   - `/Plugins/RealTimeHDRSRGAN/CreateBackup` - Backup Jellyfin config
   - `/Plugins/RealTimeHDRSRGAN/RestoreBackup` - Restore backup
   - `/Plugins/RealTimeHDRSRGAN/CheckHlsStatus` - Check HLS stream status
   - `/Plugins/RealTimeHDRSRGAN/TriggerUpscale` - Manually trigger upscaling
   - `/Plugins/RealTimeHDRSRGAN/GetHlsUrl` - Get HLS stream URL

3. **Integration**: Works with webhook plugin to receive playback events and trigger upscaling

## Integration with Webhook

The webhook plugin sends playback events to your watchdog service at `http://localhost:5000/upscale-trigger`, which then:
1. Receives the file path from webhook
2. Triggers SRGAN upscaling pipeline
3. Creates HLS stream
4. Plugin can check status and provide HLS URL to clients

## Next Steps After Plugin is Loaded

1. **Configure the plugin**:
   - Enable upscaling
   - Select GPU device
   - Set upscale factor (2x or 4x)
   - Configure HLS settings
   - Set watchdog URL

2. **Test GPU detection**:
   - Use the "Detect GPU" button in plugin settings
   - Verify NVIDIA GPU is detected

3. **Test upscaling**:
   - Play a video in Jellyfin
   - Webhook should trigger upscaling
   - Check watchdog logs for processing status

4. **Monitor logs**:
   - Jellyfin logs for plugin errors
   - Watchdog logs for upscaling pipeline
   - HLS server logs for streaming

## Quick Start Commands

```bash
# 1. Build the plugin
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin
./build-plugin.sh

# 2. Deploy (adjust for your setup)
# See deployment sections above

# 3. Restart Jellyfin
sudo systemctl restart jellyfin
# OR
docker restart jellyfin

# 4. Verify
curl http://localhost:8096/Plugins/RealTimeHDRSRGAN/Configuration

# 5. Check it appears in Dashboard → Plugins
```

Good luck! The plugin should now load successfully in Jellyfin.
