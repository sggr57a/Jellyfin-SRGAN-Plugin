# Transfer and Build Instructions

## Current Setup

- **Build Machine**: Your current Mac/development machine
- **Jellyfin Server**: Different machine where Jellyfin is running

## Files Ready to Transfer

All files are ready to be transferred to the Jellyfin server:

### Core Plugin Files:
```
jellyfin-plugin/
├── Server/
│   ├── Controllers/
│   │   └── PluginApiController.cs
│   ├── Plugin.cs
│   ├── PluginConfiguration.cs
│   ├── RealTimeHdrSrgan.Plugin.csproj
│   ├── NuGet.Config
│   └── Directory.Packages.props
├── manifest.json
├── build.yaml
├── build-plugin.sh              ← Build script (portable)
├── gpu-detection.sh
├── backup-config.sh
├── restore-config.sh
├── ConfigurationPage.html
└── ConfigurationPage.js
```

## Transfer to Jellyfin Server

### Step 1: Copy Files to Server

```bash
# From your current machine, transfer the entire plugin directory
scp -r /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin user@jellyfin-server:/tmp/

# OR use rsync
rsync -av /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin/ \
  user@jellyfin-server:/tmp/jellyfin-plugin/
```

### Step 2: SSH into Jellyfin Server

```bash
ssh user@jellyfin-server
```

### Step 3: Build on the Server

```bash
cd /tmp/jellyfin-plugin
chmod +x build-plugin.sh
./build-plugin.sh
```

The build script is portable and will:
1. Clear NuGet cache on the server
2. Restore packages from nuget.org
3. Build the plugin on the server
4. Show deployment instructions for that server

## Alternative: Build with Docker on Server

If the Jellyfin server doesn't have .NET SDK installed, the script will offer to build with Docker:

```bash
cd /tmp/jellyfin-plugin
./build-plugin.sh
# Select 'y' when prompted to build with Docker
```

## Alternative: Build Locally, Transfer DLL

If you prefer to build on your current machine and just transfer the compiled DLL:

### On Your Current Machine:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin

# Build with Docker (works on Mac)
docker run --rm \
  -v "$(pwd)/Server:/src" \
  -w /src \
  mcr.microsoft.com/dotnet/sdk:9.0 \
  sh -c "dotnet nuget locals all --clear && dotnet restore --force && dotnet clean -c Release && dotnet build -c Release"
```

### Transfer Just the Built Files:

```bash
# Copy the built DLLs to the server
scp -r Server/bin/Release/net9.0/ user@jellyfin-server:/tmp/plugin-dlls/
```

### On the Jellyfin Server:

```bash
# Stop Jellyfin
sudo systemctl stop jellyfin  # or docker stop jellyfin

# Deploy the plugin
sudo mkdir -p /var/lib/jellyfin/plugins/RealTimeHDRSRGAN
sudo cp -r /tmp/plugin-dlls/* /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/RealTimeHDRSRGAN

# Start Jellyfin
sudo systemctl start jellyfin  # or docker start jellyfin
```

## Script is Portable - No Machine-Specific Paths

The `build-plugin.sh` script uses relative paths:
- `cd "$(dirname "$0")/Server"` - Always relative to script location
- No hardcoded paths like `/Users/jmclaughlin/...`
- Works on any Linux/Mac system

## What Happens When You Run the Script on the Server

```
==========================================
RealTimeHDRSRGAN Plugin Builder
==========================================

✓ Found dotnet: 9.0.x

Clearing NuGet cache...
Cleaning previous builds...
Restoring packages...
Building plugin...

==========================================
✓ Build complete!
==========================================

Plugin DLL location:
  /tmp/jellyfin-plugin/Server/bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll

To deploy to Jellyfin:

  # For Linux (bare metal):
  sudo systemctl stop jellyfin
  sudo mkdir -p /var/lib/jellyfin/plugins/RealTimeHDRSRGAN
  sudo cp bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
  sudo systemctl start jellyfin

  # For Docker:
  docker stop jellyfin
  docker cp bin/Release/net9.0/. jellyfin:/config/plugins/RealTimeHDRSRGAN/
  docker start jellyfin
```

## Recommended Workflow

### Option A: Build on Server (Recommended)
1. Transfer source files to server
2. Run `./build-plugin.sh` on server
3. Follow deployment instructions shown by script

**Pros**: 
- Everything happens on the target machine
- Script handles all dependencies

### Option B: Build Locally with Docker
1. Build on your Mac with Docker
2. Transfer only the compiled DLLs
3. Manually copy to Jellyfin plugins directory

**Pros**: 
- Don't need .NET SDK on server
- Faster if you rebuild often

## Server Requirements

### For Building on Server:
- Docker (for Docker build method) OR
- .NET 9.0 SDK (for native build)

### For Running the Plugin:
- Jellyfin 10.11.5+
- .NET 9.0 runtime (usually included with Jellyfin)

## Quick Commands Summary

```bash
# === On Your Current Machine ===

# Transfer files
scp -r jellyfin-plugin user@jellyfin-server:/tmp/

# === On Jellyfin Server ===

# SSH in
ssh user@jellyfin-server

# Build
cd /tmp/jellyfin-plugin
chmod +x build-plugin.sh
./build-plugin.sh

# Deploy (follow instructions from script output)
sudo systemctl stop jellyfin
sudo mkdir -p /var/lib/jellyfin/plugins/RealTimeHDRSRGAN
sudo cp Server/bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/RealTimeHDRSRGAN
sudo systemctl start jellyfin
```

The script is ready to use on any machine - just transfer and run!
