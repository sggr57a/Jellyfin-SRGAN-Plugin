# Webhook Path Not Working - Troubleshooting Guide

## Problem

The webhook is not pulling the `{{Path}}` variable even though it's configured in the webhook template.

## Root Cause

**THE PLUGIN HAS NOT BEEN BUILT AND DEPLOYED**

The code changes to `DataObjectHelpers.cs` that expose the `Path` variable exist in the source code but have not been compiled into a `.dll` file that Jellyfin can use.

## Solution Steps

### Step 1: Build the Plugin

You need to build the modified webhook plugin. Choose one of these options:

#### Option A: Using dotnet CLI (if installed)

```bash
cd jellyfin-plugin-webhook
dotnet build -c Release
```

The built plugin will be in:
```
jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/Jellyfin.Plugin.Webhook.dll
```

#### Option B: Using Docker

If dotnet is not installed but you have Docker:

```bash
cd jellyfin-plugin-webhook

# Build using official .NET SDK container
docker run --rm -v "$(pwd):/src" -w /src mcr.microsoft.com/dotnet/sdk:9.0 \
  dotnet build -c Release
```

#### Option C: Using Jellyfin Build Tools

The plugin has a `build.yaml` that suggests it's part of the Jellyfin build system. Check if there's a Jellyfin plugin builder available.

### Step 2: Deploy the Plugin to Jellyfin

Once built, you need to copy the plugin DLL and its dependencies to your Jellyfin plugins directory:

#### For Linux (bare metal):
```bash
# Stop Jellyfin first
sudo systemctl stop jellyfin

# Create webhook plugin directory if it doesn't exist
sudo mkdir -p /var/lib/jellyfin/plugins/Webhook

# Copy the built files
sudo cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/*.dll \
  /var/lib/jellyfin/plugins/Webhook/

# Restart Jellyfin
sudo systemctl start jellyfin
```

#### For Docker:
```bash
# Stop Jellyfin container
docker stop jellyfin

# Copy plugin files
docker cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/. \
  jellyfin:/config/plugins/Webhook/

# Restart Jellyfin
docker start jellyfin
```

### Step 3: Verify the Plugin is Loaded

1. Log into Jellyfin web interface
2. Go to **Dashboard** → **Plugins**
3. Check that **Webhook** plugin is listed and showing the correct version
4. If not listed, check Jellyfin logs for errors

### Step 4: Configure the Webhook

1. In Jellyfin Dashboard → **Plugins** → **Webhook**
2. Add a new webhook destination (Generic Webhook)
3. Configure it with your endpoint URL
4. Set the template to include `{{Path}}`:

```json
{
  "Path": "{{Path}}",
  "Name": "{{Name}}",
  "ItemType": "{{ItemType}}",
  "ItemId": "{{ItemId}}",
  "NotificationType": "{{NotificationType}}"
}
```

5. Enable the notification types you want (e.g., PlaybackStart)
6. Save the configuration

### Step 5: Test the Webhook

1. Play a video in Jellyfin
2. Check your webhook endpoint to see if it received the POST request
3. Verify that the `Path` field is populated with the file path

## Verification Checklist

- [ ] Plugin source code has Path property addition in DataObjectHelpers.cs (lines 64-67)
- [ ] Plugin has been built successfully (check for `bin/Release/net9.0/` directory)
- [ ] Built DLL files copied to Jellyfin plugins directory
- [ ] Jellyfin has been restarted
- [ ] Webhook plugin appears in Jellyfin Dashboard → Plugins
- [ ] Webhook is configured with {{Path}} in template
- [ ] Test playback triggers the webhook
- [ ] Webhook payload contains Path field with file path

## Common Issues

### Issue 1: dotnet command not found
**Solution**: Install .NET 9.0 SDK or use Docker method

### Issue 2: Permission denied when copying to plugins folder
**Solution**: Use `sudo` for Linux or ensure Docker has proper permissions

### Issue 3: Plugin shows old version
**Solution**: Make sure to restart Jellyfin after deploying. Also check if there are multiple plugin directories.

### Issue 4: Path field is empty or null
**Possible causes**:
- Item might be a virtual item (no physical file)
- Item might be from a channel or remote source
- Check that the item being played actually has a file path

### Issue 5: Webhook not triggering at all
**Check**:
- Webhook destination is enabled
- Notification types are checked (PlaybackStart, etc.)
- Item types match (Movie, Episode, etc.)
- Check Jellyfin logs for webhook errors

## Testing Path Availability

To test if the Path property is actually available in your Jellyfin items, you can:

1. Enable verbose logging in Jellyfin
2. Check what properties are available on BaseItem
3. Verify the item has `IsFileProtocol = true` and `LocationType = FileSystem`

## Alternative: Check if Stock Plugin Works

To verify your webhook configuration is working (without Path):

1. Test with a simpler template:
```json
{
  "Name": "{{Name}}",
  "ItemType": "{{ItemType}}"
}
```

2. If this works but Path doesn't, then the plugin definitely needs to be rebuilt with the Path modification.

## Next Steps

Once you've built and deployed the plugin:

1. Test that Path is now populated in webhook payloads
2. Verify your SRGAN upscaling pipeline receives the correct file paths
3. Monitor Jellyfin logs for any errors related to the webhook plugin
