# CRITICAL: Webhook Path Not Working - Root Cause Analysis

## The Problem

The webhook is **NOT pulling the `Path` variable** even though it's configured in `jellyfin-webhook-config.json`.

## Root Cause Identified ✓

**THE MODIFIED PLUGIN HAS NOT BEEN BUILT AND DEPLOYED TO JELLYFIN**

### Why This Happened

1. ✅ The source code modification is **CORRECT** - `DataObjectHelpers.cs` properly adds the Path property (lines 64-67)
2. ✅ The webhook configuration is **CORRECT** - `jellyfin-webhook-config.json` properly requests `{{Path}}`
3. ❌ The modified plugin was **NEVER BUILT** - The `bin/Release/` directory doesn't exist
4. ❌ Even if it was built, it was **NEVER DEPLOYED** to Jellyfin's plugin directory
5. ❌ Jellyfin is likely running the **STOCK webhook plugin** that doesn't expose the Path variable

### Evidence

- Build directory check: `jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/` → **Does not exist**
- This means the .dll file with the Path modification has never been compiled
- Jellyfin can only run compiled .dll files, not source code

## The Fix

### Quick Fix (Using Docker - Recommended)

```bash
# Navigate to the plugin directory
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook

# Build using Docker (no .NET SDK needed)
docker run --rm \
  -v "$(pwd):/src" \
  -w /src/Jellyfin.Plugin.Webhook \
  mcr.microsoft.com/dotnet/sdk:9.0 \
  dotnet build -c Release

# Verify build succeeded
ls -la Jellyfin.Plugin.Webhook/bin/Release/net9.0/
```

### Alternative: Using the Build Script

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook
./build-plugin.sh
```

The script will:
1. Check if dotnet is installed
2. If not, offer to build with Docker
3. Provide deployment instructions

### Deploy to Jellyfin

After building, you need to deploy:

#### If Jellyfin is running on Linux (bare metal):
```bash
sudo systemctl stop jellyfin
sudo mkdir -p /var/lib/jellyfin/plugins/Webhook
sudo cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/*.dll \
  /var/lib/jellyfin/plugins/Webhook/
sudo systemctl start jellyfin
```

#### If Jellyfin is running in Docker:
```bash
docker stop jellyfin
docker cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/. \
  jellyfin:/config/plugins/Webhook/
docker start jellyfin
```

## Verification Steps

After deploying:

1. **Check Jellyfin recognizes the plugin:**
   - Dashboard → Plugins → Look for "Webhook" plugin

2. **Configure the webhook:**
   - Dashboard → Plugins → Webhook → Add Generic Webhook
   - Use your template with `{{Path}}`

3. **Test it:**
   - Play a video in Jellyfin
   - Check your webhook endpoint
   - Verify the Path field is now populated

## What Was Already Correct

✅ **Code modification** - DataObjectHelpers.cs correctly adds:
```csharp
if (!string.IsNullOrEmpty(item.Path))
{
    dataObject["Path"] = item.Path;
}
```

✅ **Webhook configuration** - jellyfin-webhook-config.json correctly uses:
```json
{
  "Path": "{{Path}}",
  "Name": "{{Name}}",
  ...
}
```

✅ **.NET version** - Project targets net9.0, matching your installed version

✅ **Path property** - Using the correct `item.Path` property from Jellyfin's BaseItem class

## What Was Missing

❌ **Building the plugin** - Converting source code (.cs files) to executable (.dll files)

❌ **Deploying the plugin** - Copying built .dll files to Jellyfin's plugins directory

❌ **Restarting Jellyfin** - Loading the new plugin version

## Files Created to Help You

1. **WEBHOOK_PATH_TROUBLESHOOTING.md** - Comprehensive troubleshooting guide
2. **build-plugin.sh** - Automated build script with Docker fallback
3. **This file** - Root cause analysis

## Next Steps

1. **Build the plugin** using one of the methods above
2. **Deploy to Jellyfin** using the appropriate method for your setup
3. **Restart Jellyfin** to load the new plugin
4. **Test** by playing a video and checking webhook payload
5. **Verify** that Path now contains the file path

## Expected Result

After building and deploying, your webhook endpoint should receive:

```json
{
  "Path": "/mnt/media/movies/Example.mkv",
  "Name": "Example Movie",
  "ItemType": "Movie",
  "ItemId": "...",
  "NotificationType": "PlaybackStart",
  ...
}
```

The `Path` field will now contain the actual file system path that your SRGAN upscaling pipeline needs.
