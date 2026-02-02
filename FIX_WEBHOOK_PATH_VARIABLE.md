# Fix Webhook {{Path}} Variable - Complete Guide

## Problem

Webhook template shows `{{Path}} = ''` (empty) - the Path variable is not being populated.

## Root Cause

The webhook plugin's `DataObjectHelpers.cs` file needs to be patched to expose the `item.Path` property in the webhook payload.

## Solution - Run on Your Server (192.168.101.164)

### Step 1: Pull Latest Changes

```bash
ssh root@192.168.101.164
# Password: den1ed

cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
```

### Step 2: Get Webhook Source Files (if not done)

```bash
./scripts/setup_webhook_source.sh
```

This fetches the official webhook plugin source code.

### Step 3: Apply {{Path}} Variable Patch

```bash
./scripts/patch_webhook_path.sh
```

This patches `DataObjectHelpers.cs` to add:
```csharp
if (!string.IsNullOrEmpty(item.Path))
{
    dataObject["Path"] = item.Path;
}
```

### Step 4: Rebuild and Reinstall

```bash
sudo ./scripts/install_all.sh
```

This rebuilds the webhook plugin with the patch and installs it.

### Step 5: Verify the Fix

```bash
./scripts/verify_webhook_path.sh
```

This checks:
- ✓ Webhook plugin installed
- ✓ Configuration has {{Path}} template
- ✓ DataObjectHelpers.cs has Path property
- ✓ Shows recent webhook data

### Step 6: Test with Real Playback

```bash
# Terminal 1: Monitor watchdog logs
tail -f /var/log/srgan-watchdog.log

# Terminal 2: In Jellyfin web UI, play a video
# Watch the logs for webhook data
```

Expected output:
```json
{
  "Path": "/media/movies/Example.mkv",
  "Name": "Example",
  "ItemType": "Movie",
  ...
}
```

**NOT:**
```json
{
  "Path": "",  ← This is wrong!
  ...
}
```

## What Each Script Does

### setup_webhook_source.sh
- Clones official Jellyfin webhook plugin
- Copies all source files
- Preserves custom build configuration

### patch_webhook_path.sh  
- Patches DataObjectHelpers.cs
- Adds Path property exposure
- Creates backup before patching
- Verifies patch succeeded

### verify_webhook_path.sh
- Checks webhook is installed
- Checks configuration has {{Path}}
- Checks source code has patch
- Shows recent webhook data
- Provides test instructions

## Manual Patch (if script fails)

If the patch script doesn't work, manually edit:

```bash
nano /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs
```

Find the `AddBaseItemData` method and add after `ItemId`:

```csharp
if (!string.IsNullOrEmpty(item.ItemId))
{
    dataObject["ItemId"] = item.ItemId;
}

// ADD THIS:
if (!string.IsNullOrEmpty(item.Path))
{
    dataObject["Path"] = item.Path;
}
```

Then rebuild:
```bash
cd /root/Jellyfin-SRGAN-Plugin
sudo ./scripts/install_all.sh
```

## Troubleshooting

### Path Still Empty After Patch

1. **Check plugin is actually installed:**
```bash
ls -la /var/lib/jellyfin/plugins/Webhook/
# Should show: Jellyfin.Plugin.Webhook.dll with recent timestamp
```

2. **Check Jellyfin loaded the new plugin:**
```bash
sudo systemctl restart jellyfin
sudo journalctl -u jellyfin -n 50 | grep -i webhook
```

3. **Verify configuration includes {{Path}}:**
```bash
cat /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml | grep Path
```

4. **Check watchdog is receiving webhooks:**
```bash
sudo systemctl status srgan-watchdog
curl http://localhost:5000/health
```

### Plugin Build Fails

```bash
# Clear cache and rebuild
cd /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet clean
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release -v detailed
```

### Webhook Not Triggering

1. **Check webhook is configured in Jellyfin:**
   - Dashboard → Plugins → Webhook → Settings
   - Should show "SRGAN 4K Upscaler" webhook
   - PlaybackStart should be enabled
   - URL: http://localhost:5000/upscale-trigger

2. **Reconfigure if needed:**
```bash
sudo python3 /root/Jellyfin-SRGAN-Plugin/scripts/configure_webhook.py \
  http://localhost:5000 \
  /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml
sudo systemctl restart jellyfin
```

## Expected Complete Flow

1. ✅ Pull latest code
2. ✅ Setup webhook source
3. ✅ Apply Path patch
4. ✅ Rebuild and install
5. ✅ Verify patch applied
6. ✅ Test with video playback
7. ✅ See Path in webhook data

## Quick Command Summary

```bash
# On server: 192.168.101.164
ssh root@192.168.101.164

cd /root/Jellyfin-SRGAN-Plugin
git pull
./scripts/setup_webhook_source.sh
./scripts/patch_webhook_path.sh
sudo ./scripts/install_all.sh
./scripts/verify_webhook_path.sh

# Test
tail -f /var/log/srgan-watchdog.log
# Play video in Jellyfin
# Check logs show Path
```

## Success Indicators

✅ Patch script says "Patch Complete!"  
✅ Verify script shows "✓ Path property IS exposed"  
✅ Build succeeds with no errors  
✅ Webhook data shows `"Path": "/actual/file/path.mkv"`  
✅ Watchdog receives and processes the path  

If all these pass, {{Path}} variable is working! 🎉
