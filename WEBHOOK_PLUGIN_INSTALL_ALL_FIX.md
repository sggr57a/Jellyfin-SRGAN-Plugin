# Webhook Plugin Fix - install_all.sh Updated

## Problem

The webhook plugin wasn't working and the watchdog wasn't seeing anything from Jellyfin.

## Root Causes & Fixes

### 1. Webhook Plugin Build Issues (FIXED)

**Problem**: The `install_all.sh` script had issues building the webhook plugin:
- Didn't clear NuGet cache before building
- Only copied the main DLL, not dependencies
- Didn't restart Jellyfin after installation
- Build path was incorrect

**Fixed**:
- ✅ Added cache clearing: `dotnet nuget locals all --clear`
- ✅ Added forced restore: `dotnet restore --force`
- ✅ Now copies ALL DLLs (including dependencies like Handlebars, MailKit, etc.)
- ✅ Stops Jellyfin before updating plugin
- ✅ Restarts Jellyfin after installation
- ✅ Proper error handling and status messages

### 2. Webhook Configuration (FIXED)

**Problem**: After building, the webhook wasn't configured automatically.

**Fixed**:
- ✅ Added Step 9: Automatic webhook configuration
- ✅ Uses `configure_webhook.py` to set up webhook
- ✅ Configures for PlaybackStart events
- ✅ Sets endpoint to `http://localhost:5000/upscale-trigger`
- ✅ Restarts Jellyfin to apply configuration

## What install_all.sh Now Does

### Step 2.3: Build Webhook Plugin
```bash
1. Clears NuGet cache
2. Restores packages
3. Builds the patched webhook plugin
4. Stops Jellyfin
5. Copies ALL DLLs to /var/lib/jellyfin/plugins/Webhook/
6. Sets proper ownership (jellyfin:jellyfin)
7. Restarts Jellyfin
```

### Step 9: Configure Webhook (NEW)
```bash
1. Checks if patched plugin is installed
2. Runs configure_webhook.py to create XML configuration
3. Sets up webhook for:
   - Trigger: PlaybackStart
   - Endpoint: http://localhost:5000/upscale-trigger
   - Item types: Movies, Episodes
   - Template: Includes {{Path}} variable
4. Restarts Jellyfin to load configuration
```

## How to Use

### Full Installation
```bash
cd /path/to/Jellyfin-SRGAN-Plugin
sudo ./scripts/install_all.sh
```

The script will now:
1. Install all dependencies
2. Build RealTimeHDRSRGAN plugin
3. **Build patched webhook plugin with Path support**
4. **Configure webhook automatically**
5. Install watchdog service
6. Start everything

### Manual Webhook Build (if needed)
```bash
cd /path/to/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook
./build-plugin.sh

# Then deploy
sudo systemctl stop jellyfin
sudo mkdir -p /var/lib/jellyfin/plugins/Webhook
sudo cp Jellyfin.Plugin.Webhook/bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/Webhook/
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/Webhook
sudo systemctl start jellyfin
```

### Manual Webhook Configuration (if needed)
```bash
sudo python3 scripts/configure_webhook.py \
  "http://localhost:5000" \
  "/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml"

sudo systemctl restart jellyfin
```

## Verifying Webhook is Working

### 1. Check Plugin is Loaded
```bash
# Check Jellyfin logs
sudo journalctl -u jellyfin | grep -i webhook

# Should see:
# "Jellyfin.Plugin.Webhook loaded successfully"
```

### 2. Check in Jellyfin Dashboard
1. Open Jellyfin web interface
2. Go to **Dashboard** → **Plugins**
3. Look for **Webhook** plugin
4. Click on it to see configuration
5. You should see "SRGAN 4K Upscaler" webhook configured

### 3. Check Webhook Configuration File
```bash
sudo cat /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml | grep -A 5 "SRGAN"

# Should show the webhook configuration with Path template
```

### 4. Test Webhook Manually
```bash
# Test watchdog is listening
curl http://localhost:5000/health

# Should return: {"status": "healthy"}
```

### 5. Test Full Flow
```bash
# Play a video in Jellyfin, then check watchdog logs
journalctl -u srgan-watchdog.service -f

# Should see:
# "Received playback event: PlaybackStart"
# "File path: /mnt/media/movies/..."
```

## Troubleshooting

### Issue: Webhook plugin not appearing in Dashboard

**Check**:
```bash
ls -la /var/lib/jellyfin/plugins/Webhook/
```

**Should see**:
- `Jellyfin.Plugin.Webhook.dll`
- `Handlebars.dll`
- `MailKit.dll`
- `MQTTnet.dll`
- Other dependencies

**Fix**:
```bash
# Rebuild and reinstall
cd jellyfin-plugin-webhook
./build-plugin.sh
# Follow deployment instructions
```

### Issue: Webhook not triggering

**Check configuration**:
```bash
sudo cat /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml
```

**Should contain**:
- `<WebhookName>SRGAN 4K Upscaler</WebhookName>`
- `<WebhookUri>http://localhost:5000/upscale-trigger</WebhookUri>`
- `<EnableWebhook>true</EnableWebhook>`
- Base64-encoded template with `{{Path}}`

**Fix**:
```bash
# Reconfigure
sudo python3 scripts/configure_webhook.py
sudo systemctl restart jellyfin
```

### Issue: Watchdog not receiving events

**Check watchdog is running**:
```bash
systemctl status srgan-watchdog.service
```

**Check watchdog logs**:
```bash
journalctl -u srgan-watchdog.service -f
```

**Test endpoint manually**:
```bash
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Path":"/mnt/media/test.mkv","Name":"Test","ItemType":"Movie","NotificationType":"PlaybackStart"}'
```

**Should see in logs**:
```
Received upscale trigger
File path: /mnt/media/test.mkv
```

### Issue: Path variable is empty

**Cause**: Stock webhook plugin installed (not patched version)

**Fix**:
```bash
# Check which webhook plugin is installed
ls -la /var/lib/jellyfin/plugins/Webhook/

# If only Jellyfin.Plugin.Webhook.dll exists, it's the stock version
# Rebuild and install patched version:
cd jellyfin-plugin-webhook
./build-plugin.sh
# Deploy as shown above
```

## What Makes the Patched Plugin Different

### Stock Webhook Plugin:
- ❌ Does NOT expose `{{Path}}` variable
- ❌ Cannot send file paths to external services
- ✅ Works for basic notifications

### Patched Webhook Plugin:
- ✅ Exposes `{{Path}}` variable
- ✅ Sends full file path: `/mnt/media/movies/example.mkv`
- ✅ Required for SRGAN upscaling pipeline
- ✅ All other webhook functionality intact

The patch adds these lines to `DataObjectHelpers.cs`:
```csharp
if (!string.IsNullOrEmpty(item.Path))
{
    dataObject["Path"] = item.Path;
}
```

## Files Modified

1. **scripts/install_all.sh**
   - Step 2.3: Improved webhook plugin build and deployment
   - Step 9 (NEW): Automatic webhook configuration

2. **jellyfin-plugin-webhook/** (already had the fix)
   - `Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs` - Path variable support
   - `Server/NuGet.Config` - Fixed package sources
   - `build-plugin.sh` - Build script with cache clearing

## Summary

The `install_all.sh` script now:
1. ✅ Properly builds the patched webhook plugin
2. ✅ Copies all required dependencies
3. ✅ Automatically configures the webhook
4. ✅ Restarts Jellyfin to apply changes
5. ✅ Verifies installation

After running `install_all.sh`, the webhook should be fully functional and sending file paths to the watchdog service.
