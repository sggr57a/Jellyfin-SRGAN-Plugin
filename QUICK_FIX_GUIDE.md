# Quick Fix Guide - Run This on Your Server

## 🚀 Single Command Fix

```bash
# SSH to your server
ssh root@192.168.101.164

# Navigate to repository
cd /root/Jellyfin-SRGAN-Plugin

# Pull ALL fixes
git pull origin main

# Run complete installation (does EVERYTHING automatically)
sudo ./scripts/install_all.sh
```

That's it! The script now automatically:
- ✅ Creates missing playback overlay files
- ✅ Sets up webhook source from official repository
- ✅ Applies {{Path}} patch to DataObjectHelpers.cs
- ✅ Builds both plugins with correct configuration
- ✅ Copies overlay files to Jellyfin web directory
- ✅ Configures webhook with {{Path}} template
- ✅ Restarts Jellyfin

## What Was Fixed

### Problem 1: {{Path}} Variable Empty
**Before:** `"Path": ""`  
**After:** `"Path": "/media/movies/Example.mkv"` ✅

**How:** Automatically sets up webhook source and patches `DataObjectHelpers.cs` to expose the Path property.

### Problem 2: Playback Overlay Missing
**Before:** No overlay files existed  
**After:** Complete overlay with loading indicators, progress tracking, and theme support ✅

**How:** Created all missing files and integrated installation into `install_all.sh`.

### Problem 3: Manual Multi-Step Process
**Before:** Had to run multiple scripts manually  
**After:** Single command does everything ✅

**How:** Integrated all setup steps into `install_all.sh`.

## Verification After Installation

### 1. Check Webhook Has Path Variable

```bash
# Monitor watchdog logs
tail -f /var/log/srgan-watchdog.log
```

In another terminal, play a video in Jellyfin. You should see:
```json
{
  "Path": "/media/movies/Example.mkv",  ← Should have actual path!
  "Name": "Example",
  "ItemType": "Movie"
}
```

### 2. Check Overlay Appears

1. Open Jellyfin: `http://192.168.101.164:8096`
2. Hard refresh: `Ctrl+Shift+R`
3. Play any video
4. Look at **top-right corner** for:

```
┌────────────┐
│ 🎬 Loading │  ← Appears immediately
│ 4K...      │
│ ░░░░░ 0%   │
└────────────┘
```

Then updates to:
```
┌────────────┐
│ 🎬 4K      │
│ Upscaling  │
│ ▓▓▓░░ 45%  │
│ Speed: 1.2x│
│ ETA: 2m    │
└────────────┘
```

### 3. Verify Files Are in Place

```bash
# Check overlay files
ls -lh /usr/share/jellyfin/web/playback-progress-overlay.*
# Should show:
# playback-progress-overlay.css (14KB)
# playback-progress-overlay.js (17KB)
# playback-progress-overlay-centered.css (4KB)

# Check webhook source
ls /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/
# Should show: DataObjectHelpers.cs

# Check Path patch is applied
grep '"Path".*item\.Path' /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs
# Should show: dataObject["Path"] = item.Path;
```

## If Something Goes Wrong

### Re-run Installation
```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
sudo ./scripts/install_all.sh
```

### Manual Diagnostics
```bash
# Check webhook plugin
./scripts/diagnose_webhook.sh

# Verify webhook path support
./scripts/verify_webhook_path.sh

# Check service status
./scripts/manage_watchdog.sh status
./scripts/manage_watchdog.sh logs
```

### Manual Restart
```bash
# Restart Jellyfin
sudo systemctl restart jellyfin

# Restart watchdog
sudo systemctl restart srgan-watchdog

# Check status
sudo systemctl status jellyfin
sudo systemctl status srgan-watchdog
```

## Expected Output from install_all.sh

You should see:

```
==========================================================================
Real-Time HDR SRGAN Pipeline - Automated Installation
==========================================================================

Step 2: Building and installing Jellyfin plugins...
==========================================================================
Setting up Webhook Plugin with {{Path}} Variable Support...
==========================================================================

Webhook source code not found. Setting up from official repository...
✓ Webhook source setup complete

Checking if {{Path}} patch is applied...
{{Path}} patch not found. Applying patch...
✓ {{Path}} patch applied successfully

Building Patched Webhook Plugin...
✓ Webhook plugin built successfully
  Installing to: /var/lib/jellyfin/plugins/Webhook_18.0.0.0
    ✓ Backed up existing DLL
  Copying plugin files and dependencies...
    ✓ deps.json copied
  ✓ Patched webhook plugin installed with Path support

==========================================================================
Restarting Jellyfin to load new plugins...
✓ Jellyfin restarted
✓ Jellyfin is running

Step 2.4: Configuring webhook for SRGAN pipeline...
✓ Webhook configured successfully

Step 2.5: Installing Jellyfin progress overlay...
Found Jellyfin web directory at: /usr/share/jellyfin/web
Installing progress overlay CSS...
✓ playback-progress-overlay.css installed
Installing progress overlay JavaScript...
✓ playback-progress-overlay.js installed
✓ playback-progress-overlay-centered.css installed

[... Docker and watchdog installation ...]

==========================================================================
Installation Complete!
==========================================================================

What was installed:
  ✓ Docker container (srgan-upscaler)
  ✓ Watchdog systemd service (auto-starts on boot)
  ✓ Jellyfin plugin
  ✓ Patched webhook plugin (with {{Path}} variable)
  ✓ Progress overlay (CSS/JS)
```

## Success Criteria

✅ **Installation completes without errors**  
✅ **Shows "✓ Patched webhook plugin (with {{Path}} variable)"**  
✅ **Shows "✓ Progress overlay (CSS/JS)"**  
✅ **Watchdog logs show `"Path": "/actual/path.mkv"`**  
✅ **Overlay appears in top-right corner when playing video**  
✅ **Upscaling starts automatically on playback**  

## Documentation

For more details, see:
- **COMPLETE_INSTALLATION_FIXED.md** - Full explanation of all fixes
- **FIX_WEBHOOK_PATH_VARIABLE.md** - {{Path}} variable fix details
- **PLAYBACK_PROGRESS_GUIDE.md** - Overlay usage guide

---

**That's it! Run the single command and everything should work!** 🎉
