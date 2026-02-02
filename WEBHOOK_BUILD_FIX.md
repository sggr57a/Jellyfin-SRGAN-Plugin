# Webhook Build Fix - Solution File Issue

## Problem

Getting error:
```
MSBUILD : error MSB1009: Project file does not exist.
Switch: /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook.sln
```

## Root Cause

The script was trying to build `Jellyfin.Plugin.Webhook.sln` (solution file) which doesn't exist in our setup. We only have the `.csproj` (project file).

## Fix Applied

Changed `install_all.sh` to build the `.csproj` file directly instead of looking for a `.sln` file.

## How to Fix on Your Server

### Option 1: Pull Latest Fix and Re-run

```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
sudo ./scripts/install_all.sh
```

### Option 2: Manual Webhook Setup (if needed)

If the automatic setup fails, run these steps manually:

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Step 1: Setup webhook source
./scripts/setup_webhook_source.sh

# Verify it worked
ls jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs
# Should exist!

# Step 2: Apply Path patch
./scripts/patch_webhook_path.sh

# Verify patch applied
grep '"Path".*item\.Path' jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs
# Should show: dataObject["Path"] = item.Path;

# Step 3: Build webhook manually
cd jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet clean
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release

# Step 4: Install built plugin
WEBHOOK_DLL=$(find bin/Release -name "Jellyfin.Plugin.Webhook.dll" | head -1)
WEBHOOK_DIR=$(find /var/lib/jellyfin/plugins -maxdepth 1 -type d -name "Webhook_*" | head -1)

if [[ -n "$WEBHOOK_DLL" ]] && [[ -n "$WEBHOOK_DIR" ]]; then
  echo "Installing to: $WEBHOOK_DIR"
  sudo cp "$WEBHOOK_DLL" "$WEBHOOK_DIR/"
  sudo cp bin/Release/net9.0/*.dll "$WEBHOOK_DIR/" 2>/dev/null || true
  sudo systemctl restart jellyfin
  echo "✓ Webhook plugin installed"
else
  echo "✗ Either build failed or webhook not installed from Jellyfin catalog"
fi
```

## Verification

After installation, verify the webhook works:

```bash
# 1. Check webhook plugin is installed in Jellyfin
ls -lh /var/lib/jellyfin/plugins/Webhook_*/Jellyfin.Plugin.Webhook.dll
# Should show recent timestamp

# 2. Check Path patch is in source
grep '"Path".*item\.Path' /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs
# Should show the Path property code

# 3. Test with real playback
tail -f /var/log/srgan-watchdog.log
# Play video in Jellyfin
# Should see: "Path": "/media/movies/Example.mkv"
```

## What Changed in install_all.sh

### Before (Broken):
```bash
dotnet build "${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook.sln" -c Release
# ❌ .sln file doesn't exist!
```

### After (Fixed):
```bash
WEBHOOK_CSPROJ="${WEBHOOK_PLUGIN_SRC}/Jellyfin.Plugin.Webhook/Jellyfin.Plugin.Webhook.csproj"
if [[ -f "${WEBHOOK_CSPROJ}" ]]; then
  dotnet build "${WEBHOOK_CSPROJ}" -c Release
  # ✅ Builds the .csproj file directly
fi
```

## Prerequisites

Before webhook can build, you need:

1. **Webhook installed from Jellyfin catalog**
   ```
   Dashboard → Plugins → Catalog → Search "Webhook" → Install
   ```

2. **Webhook source files present**
   ```
   jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/
   ├── Helpers/
   │   └── DataObjectHelpers.cs  ← Must exist!
   ├── Configuration/
   ├── Jellyfin.Plugin.Webhook.csproj
   └── ... (other source files)
   ```

3. **Path patch applied**
   ```csharp
   // In DataObjectHelpers.cs:
   if (!string.IsNullOrEmpty(item.Path))
   {
       dataObject["Path"] = item.Path;
   }
   ```

## Troubleshooting

### Error: "Webhook source code not found"

**Problem:** `DataObjectHelpers.cs` doesn't exist

**Solution:**
```bash
./scripts/setup_webhook_source.sh
```

This clones the official webhook plugin and copies all source files.

### Error: "{{Path}} patch not applied"

**Problem:** Path property not exposed in webhook data

**Solution:**
```bash
./scripts/patch_webhook_path.sh
```

This modifies `DataObjectHelpers.cs` to add the Path property.

### Error: "Webhook plugin not installed in Jellyfin"

**Problem:** No `Webhook_*` directory in `/var/lib/jellyfin/plugins/`

**Solution:**
1. Open Jellyfin Dashboard
2. Go to Plugins → Catalog
3. Search for "Webhook"
4. Click Install
5. Restart Jellyfin
6. Then run `install_all.sh` again

### Error: "Build failed with compilation errors"

**Problem:** C# compilation errors

**Solution:**
```bash
# Clean everything and try again
cd /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
rm -rf bin obj
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release -v detailed
```

Check the detailed output for specific errors.

## Complete Build Process

The correct order is:

```
1. Install webhook from Jellyfin catalog
   ↓
2. Setup webhook source (setup_webhook_source.sh)
   ↓
3. Apply Path patch (patch_webhook_path.sh)
   ↓
4. Build webhook (.csproj file)
   ↓
5. Copy DLL to Jellyfin plugins directory
   ↓
6. Restart Jellyfin
   ↓
7. Test with video playback
```

The updated `install_all.sh` now handles all these steps automatically!

## Quick Commands

```bash
# Full automated installation
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
sudo ./scripts/install_all.sh

# OR manual webhook setup
./scripts/setup_webhook_source.sh
./scripts/patch_webhook_path.sh
cd jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet build -c Release

# Verify everything
./scripts/diagnose_webhook.sh
./scripts/verify_webhook_path.sh

# Test
tail -f /var/log/srgan-watchdog.log
# Play video in Jellyfin
```

## Success Indicators

✅ `setup_webhook_source.sh` completes without errors  
✅ `DataObjectHelpers.cs` file exists  
✅ `patch_webhook_path.sh` shows "Patch Complete!"  
✅ `dotnet build` succeeds with no errors  
✅ `Jellyfin.Plugin.Webhook.dll` has recent timestamp  
✅ Watchdog logs show `"Path": "/actual/file/path.mkv"`  

If all these pass, the webhook is working correctly! 🎉
