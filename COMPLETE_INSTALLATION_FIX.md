# Complete Installation Fix Summary

## All Issues Resolved ✅

This document summarizes ALL fixes applied to ensure correct plugin versions, permissions, and automatic Jellyfin restart.

---

## 1. Plugin Version Alignment ✅

### RealTimeHDRSRGAN Plugin
- ✅ **Target Framework**: net9.0
- ✅ **Target ABI**: 10.11.5.0
- ✅ **Jellyfin.Controller**: 10.11.5
- ✅ **EntityFrameworkCore.Analyzers**: 9.0.11

**Files**:
- `jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj`
- `jellyfin-plugin/manifest.json`
- `jellyfin-plugin/build.yaml`

### Webhook Plugin (Patched)
- ✅ **Target Framework**: net9.0
- ✅ **Target ABI**: 10.11.5.0 (CORRECTED from 10.11.0.0)
- ✅ **Jellyfin.Controller**: 10.11.5 (CORRECTED from 10.*-*)

**Files**:
- `jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Jellyfin.Plugin.Webhook.csproj`
- `jellyfin-plugin-webhook/build.yaml`

---

## 2. Build Process Improvements ✅

### Step 2: RealTimeHDRSRGAN Plugin Build

**Added**:
```bash
cd "${REPO_DIR}/jellyfin-plugin/Server"
dotnet nuget locals all --clear      # NEW
dotnet restore --force               # NEW
dotnet build -c Release

# Improved deployment:
$SUDO chown -R jellyfin:jellyfin "${JELLYFIN_PLUGIN_DIR}"    # NEW
$SUDO chmod 644 "${JELLYFIN_PLUGIN_DIR}/"*.dll               # NEW
$SUDO chmod 755 "${JELLYFIN_PLUGIN_DIR}/"*.sh                # NEW
```

**Why**: Prevents NuGet cache issues, ensures clean builds, sets correct permissions.

### Step 2.3: Webhook Plugin Build

**Already Fixed in Previous Session**:
```bash
cd "${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook"
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release

# Stop Jellyfin before update
$SUDO systemctl stop jellyfin

# Copy ALL DLLs (including dependencies)
$SUDO cp "${WEBHOOK_OUTPUT_DIR}"/*.dll "${WEBHOOK_PLUGIN_DIR}/"
$SUDO chown -R jellyfin:jellyfin "${WEBHOOK_PLUGIN_DIR}"

# Restart Jellyfin
$SUDO systemctl start jellyfin
```

**Why**: Webhook has dependencies (Handlebars, MailKit, MQTTnet) that must be copied.

---

## 3. Automatic Webhook Configuration ✅

### Step 9: Configure Webhook Plugin

**Already Added in Previous Session**:
```bash
# Automatically configures webhook using configure_webhook.py
$SUDO python3 "${REPO_DIR}/scripts/configure_webhook.py" \
  "http://localhost:5000" \
  "/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"

# Creates XML configuration:
# - Webhook name: "SRGAN 4K Upscaler"
# - Trigger: PlaybackStart (Movies, Episodes)
# - Template includes: {{Path}} variable
# - Target: http://localhost:5000/upscale-trigger

$SUDO systemctl restart jellyfin  # Apply configuration
```

**Why**: Eliminates manual configuration, ensures {{Path}} variable is included.

---

## 4. Comprehensive Permission Fix ✅ (NEW)

### Step 10: Fix Jellyfin Permissions

**Added**:
```bash
# Recursive ownership fix
$SUDO chown -R jellyfin:jellyfin /var/lib/jellyfin

# Directory permissions (755)
$SUDO find /var/lib/jellyfin -type d -exec chmod 755 {} \;

# File permissions (644)
$SUDO find /var/lib/jellyfin -type f -exec chmod 644 {} \;

# Script permissions (755 - executable)
$SUDO find /var/lib/jellyfin/plugins -name "*.sh" -exec chmod 755 {} \;

# Verification output shows ownership for each plugin
```

**Why**:
- Ensures Jellyfin can read all plugin DLLs
- Allows Jellyfin to execute helper scripts
- Prevents "permission denied" errors
- Protects configuration files

**Permissions Breakdown**:
```
Directories (755): rwxr-xr-x
  - Owner (jellyfin): Read, Write, Execute
  - Group: Read, Execute
  - Others: Read, Execute

Files (644): rw-r--r--
  - Owner (jellyfin): Read, Write
  - Group: Read
  - Others: Read

Scripts (755): rwxr-xr-x
  - Owner (jellyfin): Read, Write, Execute
  - Group: Read, Execute
  - Others: Read, Execute
```

---

## 5. Automatic Jellyfin Restart ✅ (NEW)

### Step 11: Final Jellyfin Restart

**Added**:
```bash
# Restart Jellyfin to apply all changes
$SUDO systemctl restart jellyfin

# Wait for startup
sleep 5

# Verify status
if systemctl is-active --quiet jellyfin; then
  echo "✓ Jellyfin service is running"

  # Show status details (PID, Memory, CPU)
  systemctl status jellyfin --no-pager -l | head -10
else
  echo "⚠ Check logs: sudo journalctl -u jellyfin -n 50"
fi
```

**Why**:
- Loads both plugins immediately
- Applies webhook configuration
- No manual intervention needed
- Verifies successful restart

---

## Complete Installation Flow

```
sudo ./scripts/install_all.sh

┌─────────────────────────────────────────────────────────────┐
│ Step 1:   Check dependencies                            ✓   │
│ Step 2:   Build RealTimeHDRSRGAN plugin                 ✓   │
│           - Clear NuGet cache                           NEW │
│           - Force restore                               NEW │
│           - Set permissions                             NEW │
│ Step 2.3: Build webhook plugin                          ✓   │
│           - Clear cache, restore (DONE EARLIER)             │
│           - Copy all DLLs (DONE EARLIER)                    │
│           - Stop/start Jellyfin (DONE EARLIER)              │
│ Step 3:   Setup Docker                                  ✓   │
│ Step 4:   Setup Python environment                      ✓   │
│ Step 5:   Setup systemd watchdog                        ✓   │
│ Step 6:   Setup AI model (optional)                     ✓   │
│ Step 7:   Install progress overlay                      ✓   │
│ Step 8:   Start services                                ✓   │
│ Step 9:   Configure webhook (DONE EARLIER)              ✓   │
│ Step 10:  Fix Jellyfin permissions                      ✓   │ NEW
│           - Recursive ownership                         NEW │
│           - Directory permissions (755)                 NEW │
│           - File permissions (644)                      NEW │
│           - Script permissions (755)                    NEW │
│ Step 11:  Restart Jellyfin                              ✓   │ NEW
│           - systemctl restart jellyfin                  NEW │
│           - Verify status                               NEW │
│           - Show PID/Memory/CPU                         NEW │
└─────────────────────────────────────────────────────────────┘

Installation Complete! 🎉
```

---

## What Each Session Fixed

### Previous Session
1. ✅ Webhook plugin build process (cache clearing, dependency copying)
2. ✅ Jellyfin stop/start around webhook deployment
3. ✅ Automatic webhook configuration (Step 9)
4. ✅ Documentation: WEBHOOK_PLUGIN_INSTALL_ALL_FIX.md

### This Session
1. ✅ Plugin version alignment (Jellyfin.Controller 10.11.5)
2. ✅ RealTimeHDRSRGAN build improvements (cache clearing)
3. ✅ Comprehensive permission fix (Step 10)
4. ✅ Automatic Jellyfin restart (Step 11)
5. ✅ Updated "Next Steps" (no manual restart needed)
6. ✅ Documentation: PLUGIN_VERSIONS_VERIFIED.md, PERMISSIONS_AND_RESTART_FIX.md

---

## Files Modified

### Plugin Configuration Files
1. `jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Jellyfin.Plugin.Webhook.csproj`
   - Changed: `Jellyfin.Controller` version `10.*-*` → `10.11.5`

2. `jellyfin-plugin-webhook/build.yaml`
   - Changed: `targetAbi` from `10.11.0.0` → `10.11.5.0`

### Installation Script
3. `scripts/install_all.sh`
   - **Step 2**: Added cache clearing, forced restore, improved permissions
   - **Step 10**: NEW - Comprehensive permission fix
   - **Step 11**: NEW - Automatic Jellyfin restart with verification
   - **Next Steps**: Updated to remove manual restart instructions

---

## Verification After Installation

### 1. Check Plugin Versions
```bash
# In Jellyfin Dashboard
Dashboard → Plugins

Should show:
- Real-Time HDR SRGAN Pipeline (v1.0.0) - Active
- Webhook (v18) - Active
```

### 2. Check Permissions
```bash
ls -la /var/lib/jellyfin/plugins/

# Should show:
drwxr-xr-x jellyfin jellyfin RealTimeHDRSRGAN/
drwxr-xr-x jellyfin jellyfin Webhook/

ls -la /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
# Should show:
-rw-r--r-- jellyfin jellyfin *.dll
-rwxr-xr-x jellyfin jellyfin *.sh
```

### 3. Check Services
```bash
# Jellyfin
sudo systemctl status jellyfin
# Should show: Active: active (running)

# Watchdog
sudo systemctl status srgan-watchdog
# Should show: Active: active (running)

# Docker
docker ps | grep srgan-upscaler
# Should show: Up X minutes
```

### 4. Check Webhook Configuration
```bash
cat /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml

# Should contain:
# <ServerUrl>http://localhost:5000</ServerUrl>
# <NotificationType>PlaybackStart</NotificationType>
# <Template>...{{Path}}...</Template>
```

### 5. Test End-to-End
```bash
# 1. Play a video in Jellyfin
# 2. Check watchdog logs
tail -f /var/log/srgan-watchdog.log

# Should see:
# Received webhook: {"Path": "/path/to/video.mp4", ...}
# Processing: /path/to/video.mp4
```

---

## Troubleshooting

### Plugins Not Loading

**Check**:
```bash
sudo journalctl -u jellyfin | grep -i plugin
```

**Fix**:
```bash
# Re-run permission fix
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin
sudo find /var/lib/jellyfin/plugins -name "*.sh" -exec chmod 755 {} \;
sudo systemctl restart jellyfin
```

### Webhook Not Sending {{Path}}

**Check**:
```bash
# Is patched webhook installed?
ls -la /var/lib/jellyfin/plugins/Webhook/Jellyfin.Plugin.Webhook.dll

# Check configuration
cat /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml | grep Path
```

**Fix**:
```bash
# Rebuild and reinstall webhook
cd jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet clean
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release

sudo systemctl stop jellyfin
sudo cp bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/Webhook/
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/Webhook/
sudo systemctl start jellyfin
```

### Version Mismatch Errors

**Check**:
```bash
# Check Jellyfin version
jellyfin --version
# Should be 10.11.5 or higher

# Check installed package versions
grep "Jellyfin.Controller" jellyfin-plugin*/*/Jellyfin.Plugin.*.csproj
# Should show: Version="10.11.5"
```

**Fix**: Ensure all targetAbi values are "10.11.5.0" and rebuild

---

## Summary

### ✅ All Fixes Applied

| Issue | Fix | Status |
|-------|-----|--------|
| Plugin version mismatch | Set all to 10.11.5/.NET 9.0 | ✅ DONE |
| NuGet cache issues | Clear cache before build | ✅ DONE |
| Missing dependencies | Copy all DLLs | ✅ DONE |
| Wrong permissions | Recursive chown/chmod | ✅ DONE |
| Manual restart needed | Auto restart at end | ✅ DONE |
| Manual webhook config | Auto configure in script | ✅ DONE |
| Inconsistent $SUDO | Fixed in Step 2 | ✅ DONE |

### 📚 Documentation Created

1. **PLUGIN_VERSIONS_VERIFIED.md** - Plugin version details
2. **PERMISSIONS_AND_RESTART_FIX.md** - Permission fix details
3. **COMPLETE_INSTALLATION_FIX.md** - This file (complete summary)

### 🚀 Result

**One-command installation**:
```bash
sudo ./scripts/install_all.sh
```

**Includes**:
- ✅ Correct plugin versions (10.11.5, .NET 9.0)
- ✅ Clean NuGet cache and restore
- ✅ All dependencies copied
- ✅ Automatic webhook configuration
- ✅ Comprehensive permission fix
- ✅ Automatic Jellyfin restart
- ✅ Service verification

**No manual steps required!** 🎉

---

## Next Steps After Installation

1. **Hard-refresh browser**: Ctrl+Shift+R (loads progress overlay)
2. **Play a video**: Triggers the entire pipeline
3. **Check logs**: `tail -f /var/log/srgan-watchdog.log`
4. **Monitor**: `./scripts/manage_watchdog.sh status`

---

**Last Updated**: Feb 1, 2026
**Script Version**: install_all.sh with Steps 10 & 11
**Plugin Versions**: RealTimeHDRSRGAN 1.0.0, Webhook v18
**Target**: Jellyfin 10.11.5, .NET 9.0
