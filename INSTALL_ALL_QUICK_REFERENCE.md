# Quick Reference - Enhanced install_all.sh

## ✅ All Features Integrated

The `install_all.sh` script now includes **everything** from the rebuild and test script. You only need to run **one command**.

## Run Installation

```bash
cd /path/to/Jellyfin-SRGAN-Plugin
sudo ./scripts/install_all.sh
```

## What It Does (15 Steps)

```
Step 0:   Install dependencies (Docker, .NET 9.0, Python)
Step 1:   Verify installations
Step 2:   Build RealTimeHDRSRGAN from scratch ✨ ENHANCED
Step 2.3: Build Webhook from scratch ✨ ENHANCED
Step 3:   Setup Docker container
Step 4:   Setup Python environment
Step 5:   Setup systemd watchdog
Step 6:   Setup AI model (optional)
Step 7:   Install progress overlay
Step 8:   Start services
Step 9:   Configure webhook automatically
Step 10:  Fix all permissions
Step 11:  Restart Jellyfin
Step 12:  Wait for Jellyfin API ✨ NEW
Step 13:  Test plugin loading ✨ NEW
Step 14:  Test API endpoints ✨ NEW
Step 15:  Test plugin scripts ✨ NEW
```

## What Was Added

### Clean Builds
- ✅ Removes bin/obj before building
- ✅ Clears NuGet cache
- ✅ Forces package restore
- ✅ Shows detailed build output

### API Testing
- ✅ Tests Configuration endpoint
- ✅ Tests GPU Detection endpoint
- ✅ Shows HTTP status codes
- ✅ Displays API responses

### Script Testing
- ✅ Verifies .sh files executable
- ✅ Runs gpu-detection.sh
- ✅ Shows script output

### Better Output
- ✅ Lists all built files
- ✅ Shows file sizes
- ✅ Displays plugin locations
- ✅ Verifies services running

## Expected Output

```
✓ Build successful
✓ RealTimeHDRSRGAN plugin installed (2.3M)
✓ Webhook plugin built successfully
✓ Patched webhook plugin installed (7.2M)
✓ Jellyfin API is ready
✓ RealTimeHDRSRGAN plugin files present
✓ Webhook plugin files present
✓ Configuration API responding (200)
✓ GPU Detection API responding (200)
✓ Script is executable
✓ GPU detection script works

Installation Complete! ✅
```

## After Installation

### 1. Check Dashboard
```
http://localhost:8096
Dashboard → Plugins → Installed

Should show:
✅ Real-Time HDR SRGAN Pipeline (v1.0.0) - Active
✅ Webhook (v18) - Active
```

### 2. Test Settings Page
```
Dashboard → Plugins → Real-Time HDR SRGAN Pipeline → Settings

Should have:
✅ "Detect NVIDIA GPU" button
✅ Enable Upscaling checkbox
✅ GPU Device dropdown
✅ Upscale Factor dropdown
✅ "Create Configuration Backup" button
✅ Restore backup dropdown
```

### 3. Test End-to-End
```bash
# Play a video in Jellyfin
# Watch the logs
tail -f /var/log/srgan-watchdog.log

# Should see:
Received webhook: {"Path": "/media/movies/Example.mkv", ...}
Processing: /media/movies/Example.mkv
```

## No Separate Script Needed

❌ **DON'T RUN:** `rebuild_and_test_plugins.sh`
✅ **ONLY RUN:** `install_all.sh`

Everything is integrated!

## Files Modified

- **scripts/install_all.sh** - Enhanced with rebuild and test features

## Documentation

- **INSTALL_ALL_ENHANCED.md** - Complete details
- **REBUILD_AND_TEST_GUIDE.md** - Reference (features now in install_all.sh)
- **REBUILD_SUMMARY.md** - Reference (features now in install_all.sh)

## Quick Troubleshooting

### Build Fails
```bash
# Already handled by script - it clears cache and restores
# If still failing, check logs
sudo journalctl -u jellyfin -n 100
```

### Plugin Not Loading
```bash
# Script tests this automatically in Step 13-15
# Check output for red ✗ marks
# Re-run: sudo ./scripts/install_all.sh
```

### API Not Responding
```bash
# Script waits 30 seconds for API in Step 12
# If still failing, check Jellyfin is running
sudo systemctl status jellyfin
```

## Summary

✅ Single command: `sudo ./scripts/install_all.sh`
✅ Clean builds from scratch
✅ Comprehensive testing
✅ Detailed verification
✅ No separate scripts needed

**Everything works automatically!** 🎉
