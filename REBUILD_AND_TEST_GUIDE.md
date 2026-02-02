# Complete Plugin Rebuild and Test Guide

## Overview

This guide provides instructions for completely rebuilding both plugins from scratch, installing them, and verifying everything works correctly.

## Quick Start

On your Jellyfin server, run:

```bash
cd /path/to/Jellyfin-SRGAN-Plugin
sudo ./scripts/rebuild_and_test_plugins.sh
```

This script will:
1. ✅ Check .NET version (requires .NET 9.0)
2. ✅ Clean both plugins completely
3. ✅ Restore NuGet packages
4. ✅ Build RealTimeHDRSRGAN plugin
5. ✅ Build Webhook plugin
6. ✅ Install both plugins
7. ✅ Configure webhook automatically
8. ✅ Fix all permissions
9. ✅ Restart Jellyfin
10. ✅ Test plugin loading
11. ✅ Test API endpoints
12. ✅ Test scripts

## Prerequisites

### Required Software

1. **.NET 9.0 SDK**
   ```bash
   # Check if installed
   dotnet --version
   
   # Should show: 9.0.x
   ```

   **If not installed:**
   ```bash
   # Ubuntu/Debian
   wget https://dot.net/v1/dotnet-install.sh
   chmod +x dotnet-install.sh
   sudo ./dotnet-install.sh --channel 9.0
   
   # Or download from:
   # https://dotnet.microsoft.com/download/dotnet/9.0
   ```

2. **Jellyfin 10.11.5+**
   ```bash
   # Check version
   jellyfin --version
   
   # Or check via systemctl
   systemctl status jellyfin
   ```

3. **Python 3** (for webhook configuration)
   ```bash
   python3 --version
   ```

### If .NET is Not Available

Use Docker to build:

```bash
cd /path/to/Jellyfin-SRGAN-Plugin

# Run rebuild script in Docker
docker run --rm \
  -v "$(pwd):/src" \
  -w /src \
  mcr.microsoft.com/dotnet/sdk:9.0 \
  bash scripts/rebuild_and_test_plugins.sh
```

## What the Rebuild Script Does

### Step-by-Step Process

#### 1. Check .NET Installation
```bash
✓ .NET SDK found: 9.0.203
Installed SDKs:
  9.0.203 [/usr/share/dotnet/sdk]
Installed Runtimes:
  Microsoft.AspNetCore.App 9.0.11
  Microsoft.NETCore.App 9.0.11
```

#### 2. Locate Jellyfin
```bash
✓ Jellyfin found at: /usr/lib/jellyfin/bin
  Jellyfin version: 10.11.5.0
```

#### 3. Clean RealTimeHDRSRGAN Plugin
```bash
Removing bin/ and obj/ directories...
✓ Clean complete
```

#### 4. Build RealTimeHDRSRGAN Plugin
```bash
Clearing NuGet cache...
Restoring packages...
Building plugin (Release configuration)...
✓ Build successful

Build output: jellyfin-plugin/Server/bin/Release/net9.0
DLLs and files:
  Jellyfin.Plugin.RealTimeHdrSrgan.dll
  Jellyfin.Controller.dll
  Microsoft.EntityFrameworkCore.Analyzers.dll
  gpu-detection.sh
  backup-config.sh
  restore-config.sh
```

#### 5. Install RealTimeHDRSRGAN Plugin
```bash
Installation directory: /var/lib/jellyfin/plugins/RealTimeHDRSRGAN
Stopping Jellyfin...
Copying plugin files...
Setting permissions...
✓ RealTimeHDRSRGAN plugin installed
```

#### 6-8. Clean, Build, Install Webhook Plugin
```bash
✓ Webhook plugin installed

Installed files:
  Jellyfin.Plugin.Webhook.dll
  Jellyfin.Controller.dll
  Handlebars.dll
  MailKit.dll
  MimeKit.dll
  BouncyCastle.Cryptography.dll
  MQTTnet.dll
  MQTTnet.Extensions.ManagedClient.dll
```

#### 9. Configure Webhook
```bash
Running webhook configuration script...
✓ Webhook configured
  Target: http://localhost:5000/upscale-trigger
  Trigger: PlaybackStart (Movies, Episodes)
  Template includes: {{Path}}
```

#### 10. Fix Permissions
```bash
Setting ownership: jellyfin:jellyfin
Setting directory permissions: 755
Setting file permissions: 644
Setting script permissions: 755
✓ Permissions fixed
```

#### 11. Start Jellyfin
```bash
Starting Jellyfin...
Waiting for Jellyfin to start...
✓ Jellyfin is running
```

#### 12-15. Tests
```bash
✓ Jellyfin API is ready
✓ RealTimeHDRSRGAN plugin files present
✓ Webhook plugin files present
✓ Configuration API responding (200)
✓ GPU Detection API responding (200)
✓ Script is executable
✓ GPU detection script works
```

## Manual Verification Steps

### 1. Check Plugins in Dashboard

Open Jellyfin in your browser:
```
http://your-server:8096
```

Navigate to:
```
Dashboard → Plugins → Installed
```

You should see:
- **Real-Time HDR SRGAN Pipeline** (v1.0.0) - Status: **Active** ✅
- **Webhook** (v18) - Status: **Active** ✅

### 2. Test RealTimeHDRSRGAN Settings Page

Click on **Real-Time HDR SRGAN Pipeline** → **Settings**

The page should load and display:

#### GPU Detection Section
```
┌─────────────────────────────────────────┐
│ GPU Detection                           │
│                                         │
│ [Detect NVIDIA GPU]                     │
│                                         │
│ ✓ NVIDIA GPU detected and ready!       │
│ GPU 0: NVIDIA GeForce RTX 4090         │
└─────────────────────────────────────────┘
```

#### Plugin Settings Section
```
┌─────────────────────────────────────────┐
│ Plugin Settings                         │
│                                         │
│ ☐ Enable HDR Upscaling                 │
│ ☐ Enable Transcoding Integration       │
│                                         │
│ GPU Device Selection:                   │
│ [0 - Auto-detect ▼]                     │
│                                         │
│ Upscale Factor:                         │
│ [2x ▼]                                  │
└─────────────────────────────────────────┘
```

#### Backup & Restore Section
```
┌─────────────────────────────────────────┐
│ Backup & Restore                        │
│                                         │
│ [Create Configuration Backup]           │
│                                         │
│ Restore from Backup:                    │
│ [Select a backup... ▼] [Restore]       │
└─────────────────────────────────────────┘
```

**If the page shows "Can't gather plugin details":**
- The plugin is not loaded correctly
- Check Jellyfin logs: `sudo journalctl -u jellyfin -n 50`

### 3. Test Webhook Settings Page

Click on **Webhook** → **Settings**

You should see:
- **SRGAN 4K Upscaler** webhook configured
- Destination: `http://localhost:5000/upscale-trigger`
- Events: PlaybackStart enabled

### 4. Test API Endpoints Manually

```bash
# Test configuration endpoint
curl -v http://localhost:8096/Plugins/RealTimeHDRSRGAN/Configuration

# Expected: 200 OK with JSON response
{
  "enableUpscaling": false,
  "enableTranscoding": false,
  "gpuDevice": "0",
  "upscaleFactor": "2"
}

# Test GPU detection
curl -X POST http://localhost:8096/Plugins/RealTimeHDRSRGAN/DetectGPU

# Expected: 200 OK with JSON response
{
  "available": true,
  "output": "GPU detection output...",
  "error": "",
  "gpus": []
}
```

### 5. Test Scripts

```bash
# Test GPU detection script
sudo -u jellyfin bash /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/gpu-detection.sh

# Expected output:
SUCCESS: NVIDIA GPU detected
GPU 0: NVIDIA GeForce RTX 4090

# Test backup script
sudo -u jellyfin bash /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/backup-config.sh

# Expected: Creates backup in /var/lib/jellyfin/backups/
```

### 6. Check File Permissions

```bash
# Check RealTimeHDRSRGAN
ls -la /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/

# Expected:
drwxr-xr-x jellyfin jellyfin .
-rw-r--r-- jellyfin jellyfin Jellyfin.Plugin.RealTimeHdrSrgan.dll
-rw-r--r-- jellyfin jellyfin Jellyfin.Controller.dll
-rwxr-xr-x jellyfin jellyfin gpu-detection.sh
-rwxr-xr-x jellyfin jellyfin backup-config.sh
-rwxr-xr-x jellyfin jellyfin restore-config.sh

# Check Webhook
ls -la /var/lib/jellyfin/plugins/Webhook/

# Expected:
drwxr-xr-x jellyfin jellyfin .
-rw-r--r-- jellyfin jellyfin Jellyfin.Plugin.Webhook.dll
-rw-r--r-- jellyfin jellyfin Handlebars.dll
-rw-r--r-- jellyfin jellyfin MailKit.dll
# ... other DLLs
```

### 7. Test End-to-End

1. **Start watchdog service** (if not running):
   ```bash
   sudo systemctl start srgan-watchdog
   sudo systemctl status srgan-watchdog
   ```

2. **Play a video in Jellyfin**:
   - Open Jellyfin web interface
   - Navigate to a movie or episode
   - Click play

3. **Check watchdog logs**:
   ```bash
   tail -f /var/log/srgan-watchdog.log
   ```

   Expected output:
   ```
   Received webhook: {"Path": "/media/movies/Example.mkv", "Name": "Example", ...}
   Processing: /media/movies/Example.mkv
   Starting upscale pipeline...
   ```

## Troubleshooting

### Build Errors

#### Error: "Package 'Jellyfin.Controller' not found"

**Solution**:
```bash
cd jellyfin-plugin/Server
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release
```

#### Error: "NETSDK1064: Package Microsoft.EntityFrameworkCore.Analyzers not found"

**Solution**: Already fixed in `.csproj` - rebuild from scratch:
```bash
sudo ./scripts/rebuild_and_test_plugins.sh
```

#### Error: "Target framework 'net9.0' not found"

**Solution**: Install .NET 9.0 SDK:
```bash
wget https://dot.net/v1/dotnet-install.sh
sudo bash dotnet-install.sh --channel 9.0
```

### Plugin Not Loading

#### Symptom: Plugin shows in list but "Can't gather plugin details"

**Check logs**:
```bash
sudo journalctl -u jellyfin -n 100 | grep -i "realtimehdr\|plugin"
```

**Common causes**:
1. **Missing dependencies**: Ensure all DLLs are copied
2. **Wrong permissions**: Run permission fix
3. **Wrong target ABI**: Rebuild with correct Jellyfin.Controller version

**Solution**:
```bash
# Re-run rebuild script
sudo ./scripts/rebuild_and_test_plugins.sh

# Or manually:
sudo systemctl stop jellyfin
sudo rm -rf /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/*
# Copy new DLLs
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/
sudo systemctl start jellyfin
```

#### Symptom: API endpoints return 404

**Check controller is loaded**:
```bash
sudo journalctl -u jellyfin | grep -i "controller\|api\|route"
```

**Solution**: Ensure `PluginApiController.cs` is in the build:
```bash
cd jellyfin-plugin/Server
dotnet build -c Release -v detailed | grep Controller
```

### Permission Issues

#### Error: "Permission denied" in logs

**Solution**:
```bash
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin
sudo find /var/lib/jellyfin/plugins -name "*.sh" -exec chmod 755 {} \;
sudo systemctl restart jellyfin
```

### Webhook Not Working

#### Symptom: No webhooks received by watchdog

**Check webhook config**:
```bash
cat /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml
```

Should contain:
```xml
<ServerUrl>http://localhost:5000</ServerUrl>
<NotificationType>PlaybackStart</NotificationType>
<Template>...{{Path}}...</Template>
```

**Solution**:
```bash
sudo python3 scripts/configure_webhook.py "http://localhost:5000" "/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"
sudo systemctl restart jellyfin
```

## Expected Test Results

After running the rebuild script, you should see:

### ✅ Success Indicators

```
Step 1: Checking .NET installation...
✓ .NET SDK found: 9.0.203
✓ .NET 9.0 SDK available

Step 4: Building RealTimeHDRSRGAN plugin from scratch...
✓ Build successful

Step 7: Building Webhook plugin from scratch...
✓ Build successful

Step 11: Starting Jellyfin...
✓ Jellyfin is running

Step 12: Waiting for Jellyfin API...
✓ Jellyfin API is ready

Step 13: Testing plugin loading...
✓ RealTimeHDRSRGAN plugin files present
✓ Webhook plugin files present

Step 14: Testing plugin API endpoints...
✓ Configuration API responding (200)
✓ GPU Detection API responding (200)

Step 15: Testing plugin scripts...
✓ Script is executable
✓ GPU detection script works

Rebuild and Installation Complete! ✅
```

### ⚠️ Warning Indicators (Non-Critical)

```
⚠ GPU Detection API requires authentication (401)
  This is normal - plugin is loaded
```
This is expected if accessing API without authentication. The plugin is still working.

```
⚠ GPU detection script ran but no GPU found
```
Normal if running on a system without NVIDIA GPU. The plugin still loads.

### ❌ Error Indicators (Critical)

```
✗ .NET SDK not found
✗ Build failed
✗ Jellyfin failed to start
✗ Configuration API not responding (500)
✗ RealTimeHDRSRGAN plugin DLL missing
```

If you see these, follow the troubleshooting steps above.

## Summary

The `rebuild_and_test_plugins.sh` script provides a complete, automated way to:

1. ✅ Verify your environment (.NET, Jellyfin)
2. ✅ Clean and rebuild both plugins from scratch
3. ✅ Install plugins correctly with all dependencies
4. ✅ Configure webhook automatically
5. ✅ Fix all permissions
6. ✅ Test that everything works

After running the script, both plugins should be **Active** in Jellyfin Dashboard, settings pages should load correctly with all buttons and indicators visible, and the end-to-end pipeline should work when playing videos.

**Run the script on your Jellyfin server:**
```bash
sudo ./scripts/rebuild_and_test_plugins.sh
```

Then follow the manual verification steps to ensure everything is working! 🎉
