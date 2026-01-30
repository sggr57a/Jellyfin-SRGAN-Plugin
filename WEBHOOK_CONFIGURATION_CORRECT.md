# Jellyfin Webhook Configuration (Patched Plugin)

## Important: Patched Webhook Plugin Required

The stock Jellyfin webhook plugin **does not expose the `Path` variable**. This repository includes a patched version that adds `{{Path}}` support.

### ✅ How Jellyfin Webhook Variables Work (Patched Version)

The `{{Path}}` variable comes from the `BaseItem.Path` property in Jellyfin's data model. With the patch applied, this is available when:

1. **Notification Type** = `PlaybackStart` (or `PlaybackStop`, `PlaybackProgress`)
2. **Item Type** matches the media being played (`Movie` or `Episode`)
3. The webhook template uses proper Handlebars syntax: `{{Path}}`
4. **The patched webhook plugin is installed** (see "Building and Installing" section below)

### ❌ Common Mistakes That Cause Empty {{Path}}

| Issue | Result | Fix |
|-------|--------|-----|
| Wrong Notification Type selected | Variables stay empty | ✅ Check **Playback Start** |
| Item Type not selected | Webhook doesn't fire | ✅ Check **Movie** and **Episode** |
| Wrong template syntax `{{{Path}}}` (triple braces) | Variable doesn't render | ✅ Use **double braces** `{{Path}}` |
| Nested structure `{{Item.Path}}` | Variable not found | ✅ Use flat structure `{{Path}}` |
| Stock plugin without patch | Path not available | ✅ Install patched plugin |
| Content-Type not set to JSON | Cannot parse payload | ✅ Set to `application/json` |

## Correct Configuration Steps

### Step 1: Install Jellyfin Webhook Plugin

1. Jellyfin Dashboard → **Plugins** → **Catalog**
2. Find and install **Webhooks**
3. Restart Jellyfin server

### Step 2: Create Webhook Destination

1. Dashboard → **Plugins** → **Webhooks**
2. Click **Add Generic Destination**
3. Configure as follows:

#### Basic Settings

```
Webhook Name: SRGAN 4K Upscaler
Webhook Url: http://YOUR_SERVER_IP:5000/upscale-trigger
```

Replace `YOUR_SERVER_IP` with:
- Your server's IP address (e.g., `192.168.1.100`)
- Or `localhost` if watchdog runs on same machine as Jellyfin
- Or Docker container name if using Docker network (e.g., `watchdog`)

#### Notification Type (Critical!)

**✅ CHECK EXACTLY ONE:**
- ☑ **Playback Start**

**❌ UNCHECK ALL OTHERS:**
- ☐ Item Added
- ☐ Playback Stop
- ☐ User Data Saved
- ☐ Authentication Success
- ☐ etc.

**Why:** Only `Playback Start` has the media item context needed to populate `{{Path}}`.

#### Item Type (Critical!)

**✅ CHECK BOTH:**
- ☑ **Movie**
- ☑ **Episode**

**❌ UNCHECK ALL OTHERS:**
- ☐ Audio
- ☐ Book
- ☐ Series
- ☐ Season
- ☐ etc.

**Why:** Only Movies and Episodes have file paths. Checking wrong types will send empty payloads.

#### User Filter (Optional)

Leave blank to trigger for all users, or specify user IDs to limit triggering.

#### Request Content Type (Critical!)

**✅ SELECT:**
```
application/json
```

**❌ NOT:**
- `application/x-www-form-urlencoded`
- Any other content type

**Why:** The watchdog expects JSON payloads. Wrong content-type will cause parsing errors.

#### Template Body (Critical!)

**✅ CORRECT TEMPLATE (Flat Structure):**

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

**❌ WRONG TEMPLATE (Nested Structure - Old Version):**

```json
{
  "Item": {
    "Path": "{{Item.Path}}",
    "Name": "{{Item.Name}}"
  }
}
```

**Why:** Jellyfin webhook templates use a **flat variable namespace**, not nested objects. Variables like `{{Path}}` are top-level, not `{{Item.Path}}`.

### Step 3: Save and Test

1. Click **Save**
2. Start playing a video in Jellyfin
3. Check watchdog logs: `./scripts/manage_watchdog.sh logs`
4. You should see:
   ```
   Full payload: {
     "Path": "/path/to/video.mkv",
     "Name": "Movie Name",
     ...
   }
   ```

## Troubleshooting

### Problem: `Path` is Empty String

**Symptoms:**
```
ERROR: Template variables are EMPTY ({{Path}} = '')
```

**Causes:**
1. Wrong Notification Type selected (not Playback Start)
2. Item Type doesn't match (playing Series but only Movie checked)
3. Stock webhook plugin without Path patch

**Solution:**
1. Check **Playback Start** under Notification Type
2. Check **Movie** and **Episode** under Item Type
3. Install patched webhook plugin (see below)

### Problem: `Path` Key Missing

**Symptoms:**
```
ERROR: No file path found in webhook payload!
Received keys: ['Name', 'ItemType', ...]
```

**Causes:**
1. Stock webhook plugin (doesn't have Path variable)
2. Very old Jellyfin version

**Solution:**
1. Install patched webhook plugin (see below)
2. Upgrade Jellyfin to 10.8+

### Problem: Variables Show as Literal Text

**Symptoms:**
```json
{
  "Path": "{{Path}}"
}
```

**Causes:**
1. Wrong Content-Type (not JSON)
2. Jellyfin not processing Handlebars template

**Solution:**
1. Set Request Content Type to `application/json`
2. Restart Jellyfin after changing webhook config

### Problem: Webhook Not Firing at All

**Symptoms:**
- No entries in watchdog logs when playing video
- Jellyfin shows no webhook activity

**Causes:**
1. Item Type mismatch (playing Episode but only Movie checked)
2. Webhook URL unreachable
3. Webhook plugin not enabled

**Solution:**
1. Check **both** Movie and Episode in Item Type
2. Test URL: `curl http://YOUR_SERVER_IP:5000/health`
3. Restart Jellyfin to activate webhook plugin

## Example Payloads

### ✅ Correct Payload (Flat Structure)

```json
{
  "Path": "/mnt/media/movies/Sample.mkv",
  "Name": "Sample Movie",
  "ItemType": "Movie",
  "ItemId": "a1b2c3d4e5f6",
  "NotificationUsername": "admin",
  "UserId": "1234567890",
  "NotificationType": "PlaybackStart",
  "ServerName": "MyJellyfinServer"
}
```

### ❌ Wrong Payload (Nested Structure)

```json
{
  "Item": {
    "Path": "/mnt/media/movies/Sample.mkv",
    "Name": "Sample Movie"
  }
}
```

## Configuration File Reference

Use the provided `jellyfin-webhook-config.json` as a reference. Note that Jellyfin doesn't support importing JSON configs directly - you must configure manually through the web UI.

## Building and Installing the Patched Webhook Plugin

The `{{Path}}` variable requires a patched version of the Jellyfin webhook plugin:

```bash
cd jellyfin-plugin-webhook
dotnet build -c Release
```

Install the built plugin DLL to your Jellyfin plugins directory:
```bash
# Linux
sudo cp bin/Release/net8.0/Jellyfin.Plugin.Webhook.dll /var/lib/jellyfin/plugins/Webhook/

# Docker
docker cp bin/Release/net8.0/Jellyfin.Plugin.Webhook.dll jellyfin:/config/plugins/Webhook/
```

Then restart Jellyfin to load the patched plugin.

**Automated Installation:**

If you're using `scripts/install_all.sh`, the patched webhook plugin will be built and installed automatically when the `jellyfin-plugin-webhook` directory is present.

## See Also

- Official Jellyfin Webhook Plugin: https://github.com/jellyfin/jellyfin-plugin-webhook
- Jellyfin API Documentation: https://api.jellyfin.org
- Troubleshooting Guide: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
