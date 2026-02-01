# Webhook Path Issue - Complete Action Plan

## Problem Summary

**The webhook is not pulling the `Path` variable because the modified plugin has never been built and deployed to Jellyfin.**

## Root Cause

The source code has the correct modification to expose `{{Path}}`, but:
1. The plugin has never been compiled (`.dll` file doesn't exist)
2. The compiled plugin has never been deployed to Jellyfin
3. Jellyfin is running the stock webhook plugin that doesn't expose Path

## Immediate Action Required

### STEP 1: Build the Modified Webhook Plugin

You have 3 options:

#### Option A: Using Docker (Recommended - no .NET SDK needed)

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook

docker run --rm \
  -v "$(pwd):/src" \
  -w /src/Jellyfin.Plugin.Webhook \
  mcr.microsoft.com/dotnet/sdk:9.0 \
  dotnet build -c Release

# Verify build succeeded
ls -la Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.dll
```

#### Option B: Using the Build Script

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook
./build-plugin.sh
```

#### Option C: Install .NET SDK and Build Directly

```bash
# Install .NET 9.0 SDK (macOS)
brew install dotnet@9

# Build the plugin
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook
cd Jellyfin.Plugin.Webhook
dotnet build -c Release
```

### STEP 2: Locate Your Jellyfin Installation

You need to find where Jellyfin is installed. Check:

#### If Jellyfin is in Docker:
```bash
docker ps -a | grep jellyfin
docker inspect jellyfin | grep -A 10 Mounts
```

Look for the plugins directory mount, typically:
- `/config/plugins/` inside container
- Maps to a host directory

#### If Jellyfin is bare metal (Linux):
```bash
ls -la /var/lib/jellyfin/plugins/
```

#### If Jellyfin is bare metal (macOS):
```bash
ls -la ~/Library/Application\ Support/jellyfin/plugins/
```

### STEP 3: Deploy the Plugin

Once you know where Jellyfin plugins are located:

#### For Docker Jellyfin:
```bash
# Stop Jellyfin
docker stop jellyfin

# Copy plugin (adjust paths as needed)
docker cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/. \
  jellyfin:/config/plugins/Webhook/

# Start Jellyfin
docker start jellyfin
```

#### For Bare Metal Jellyfin (Linux):
```bash
# Stop Jellyfin
sudo systemctl stop jellyfin

# Create directory
sudo mkdir -p /var/lib/jellyfin/plugins/Webhook

# Copy all DLLs
sudo cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/*.dll \
  /var/lib/jellyfin/plugins/Webhook/

# Set permissions
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/Webhook

# Start Jellyfin
sudo systemctl start jellyfin
```

#### For Bare Metal Jellyfin (macOS):
```bash
# Stop Jellyfin (adjust command if different)
# If using homebrew service:
brew services stop jellyfin

# Copy plugin
mkdir -p ~/Library/Application\ Support/jellyfin/plugins/Webhook
cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/*.dll \
  ~/Library/Application\ Support/jellyfin/plugins/Webhook/

# Start Jellyfin
brew services start jellyfin
```

### STEP 4: Verify Plugin is Loaded

1. Open Jellyfin web interface (typically http://localhost:8096)
2. Go to **Dashboard** → **Plugins**
3. Look for "Webhook" plugin
4. Verify version matches your build

### STEP 5: Configure Webhook (If Not Already Done)

1. Dashboard → Plugins → Webhook → **Add Generic Webhook**
2. Configure:
   - **Webhook Name**: SRGAN 4K Upscaler
   - **Webhook Url**: http://YOUR_SERVER_IP:5000/upscale-trigger
   - **Notification Type**: Enable "Playback Start"
   - **Item Type**: Enable "Movie" and "Episode"
   - **Template**: Use your JSON template with `{{Path}}`

```json
{
  "Path": "{{Path}}",
  "Name": "{{Name}}",
  "ItemType": "{{ItemType}}",
  "ItemId": "{{ItemId}}",
  "NotificationUsername": "{{NotificationUsername}}",
  "UserId": "{{UserId}}",
  "NotificationType": "{{NotificationType}}",
  "ServerName": "{{ServerName}}"
}
```

3. Save configuration

### STEP 6: Test the Webhook

1. Play a video in Jellyfin
2. Monitor your webhook endpoint (the Flask app at port 5000)
3. Check if you receive a POST request with the Path field populated

## Troubleshooting

### If Path is still empty:

1. **Check Jellyfin logs** for webhook errors:
   ```bash
   # Docker
   docker logs jellyfin | grep -i webhook
   
   # Linux
   sudo journalctl -u jellyfin | grep -i webhook
   
   # Or check log files
   tail -f /var/log/jellyfin/log_*.txt
   ```

2. **Verify the item has a file path**:
   - Virtual items (channels, live TV) may not have paths
   - Check that `item.IsFileProtocol == true`

3. **Test with a simpler template first**:
   ```json
   {
     "Name": "{{Name}}",
     "ItemType": "{{ItemType}}"
   }
   ```
   If this works, the webhook mechanism is fine, just Path isn't exposed.

### If webhook doesn't trigger at all:

1. Check webhook is enabled in Jellyfin
2. Check notification types are selected
3. Check item types are selected
4. Verify webhook URL is reachable from Jellyfin

## Expected Result

After completing these steps, when you play a video, your webhook endpoint should receive:

```json
{
  "Path": "/mnt/media/movies/Example.mkv",
  "Name": "Example Movie",
  "ItemType": "Movie",
  "ItemId": "abc123",
  "NotificationUsername": "User",
  "UserId": "user123",
  "NotificationType": "PlaybackStart",
  "ServerName": "My Jellyfin Server"
}
```

The SRGAN upscaling pipeline can then use the `Path` value to locate and process the video file.

## Files Created to Help

1. **build-plugin.sh** - Automated build script
2. **WEBHOOK_PATH_TROUBLESHOOTING.md** - Detailed troubleshooting guide
3. **CRITICAL_PATH_NOT_WORKING.md** - Root cause analysis
4. **This file** - Complete action plan

## Quick Command Reference

```bash
# Build with Docker
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook
docker run --rm -v "$(pwd):/src" -w /src/Jellyfin.Plugin.Webhook \
  mcr.microsoft.com/dotnet/sdk:9.0 dotnet build -c Release

# For Docker Jellyfin deployment
docker stop jellyfin
docker cp Jellyfin.Plugin.Webhook/bin/Release/net9.0/. jellyfin:/config/plugins/Webhook/
docker start jellyfin

# For Linux Jellyfin deployment
sudo systemctl stop jellyfin
sudo mkdir -p /var/lib/jellyfin/plugins/Webhook
sudo cp Jellyfin.Plugin.Webhook/bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/Webhook/
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/Webhook
sudo systemctl start jellyfin
```

## Next Steps After Fix

Once Path is working:
1. Test the complete SRGAN upscaling workflow
2. Monitor for any errors in the upscaling pipeline
3. Verify upscaled videos are being created
4. Check that Jellyfin can play the upscaled versions

Good luck! The code is correct, it just needs to be built and deployed.
