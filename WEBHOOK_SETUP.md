⚠️ DEPRECATED: This file (WEBHOOK_SETUP.md) is now outdated.

The webhook configuration has been updated to use a patched Jellyfin webhook plugin
that includes Path variable support.

Please see WEBHOOK_CONFIGURATION_CORRECT.md for the current setup instructions.

Key changes:
- Stock webhook plugin doesn't expose {{Path}} variable
- Patched plugin (in jellyfin-plugin-webhook/) adds Path support  
- Template structure changed from nested ({{Item.Path}}) to flat ({{Path}})
- install_all.sh now builds and installs the patched plugin automatically

For details, see:
- WEBHOOK_CONFIGURATION_CORRECT.md - Complete setup guide
- jellyfin-plugin-webhook/PATCH_NOTES.md - What was patched and why
# Jellyfin Webhook Configuration Guide

Quick reference for setting up the Jellyfin Webhook plugin to trigger SRGAN upscaling.

## Prerequisites

1. ✅ Watchdog running: `python3 scripts/watchdog.py`
2. ✅ Docker container built: `docker compose build srgan-upscaler`
3. ✅ Flask installed: `pip3 install flask requests`

**Verify prerequisites:**
```bash
python3 scripts/verify_setup.py
```

## Jellyfin Webhook Plugin Configuration

### Step 1: Install Webhook Plugin

1. Open Jellyfin Dashboard
2. Go to **Plugins** → **Catalog**
3. Find and install **Webhooks**
4. Restart Jellyfin

### Step 2: Add Webhook

1. Go to **Dashboard** → **Plugins** → **Webhooks** → **Add Generic Destination**
2. Fill in ALL the configuration fields below

**⚠️ THREE CRITICAL SETTINGS:**
1. **Notification Type** must be "Playback Start" (Step 2)
2. **Item Type** must be "Movie" and "Episode" (Step 2)
3. **Request Content Type** must be "application/json" (Step 4)

**If any of these are wrong, the webhook will fail!**

Configuration fields:

```
┌─────────────────────────────────────────────────────────────────┐
│ Webhook Name:                                                   │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ SRGAN Upscaler                                              │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ Webhook Url:                                                    │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ http://YOUR_SERVER_IP:5000/upscale-trigger                 │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ Notification Type:  ⚠️ MUST CHECK "Playback Start"            │
│ ☑ Playback Start    ☐ Playback Stop    ☐ Other types...       │
│      ↑ CHECK THIS!                                              │
│                                                                 │
│ Item Type:  ⚠️ MUST CHECK "Movie" AND "Episode"                │
│ ☑ Movie    ☑ Episode    ☐ Audio    ☐ Other types...           │
│   ↑ CHECK!   ↑ CHECK!                                           │
│                                                                 │
│ User Filter: (leave blank for all users)                       │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                                                             │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Why these settings matter:**
- **Playback Start**: Triggers when you start playing a video
  - Without this: Template variables like `{{Item.Path}}` will be empty
- **Movie & Episode**: Tells Jellyfin which media types to monitor
  - Without this: Webhook won't fire for your videos

### Step 3: Configure Request Template

In the **Template** field, paste this JSON exactly:

```json
{
  "Item": {
    "Path": "{{Item.Path}}",
    "Name": "{{Item.Name}}",
    "Type": "{{Item.Type}}"
  },
  "User": {
    "Name": "{{User.Name}}"
  },
  "Event": "PlaybackStart"
}
```

**Important Notes:**
- ⚠️ Use **double curly braces** `{{ }}` - this is Jellyfin's template syntax
- ⚠️ The `"Path": "{{Item.Path}}"` field is **REQUIRED**
- Other fields are optional but recommended for logging

### Step 4: Set Request Content Type ⚠️ CRITICAL

**This is the most common configuration mistake!**

In the webhook configuration, find the **Request Content Type** dropdown and set it to:

```
application/json
```

**DO NOT use:**
- ❌ `application/x-www-form-urlencoded` (will fail)
- ❌ `text/plain` (will fail)
- ❌ Leave blank (will fail)

**Visual guide:**
```
┌─────────────────────────────────────────┐
│ Request Content Type:                   │
│ ┌─────────────────────────────────────┐ │
│ │ application/json              ▼    │ │  ← Select this!
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Why this matters:**
- The watchdog endpoint expects JSON data
- Without the correct Content-Type header, Flask cannot parse the request
- You'll get error: "Invalid JSON payload"

### Step 5: Save Configuration

Click **Save** at the bottom of the form.

## Testing the Webhook

### Quick Test

```bash
# Test with a real video file from your library
python3 scripts/test_webhook.py --test-file /mnt/media/movies/sample.mkv
```

Expected output:
```
✓ Health Check PASSED
✓ Webhook test PASSED
```

### Manual Test with curl

```bash
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "Item": {
      "Path": "/mnt/media/movies/sample.mkv",
      "Name": "Test Movie",
      "Type": "Movie"
    },
    "User": {
      "Name": "TestUser"
    },
    "Event": "PlaybackStart"
  }'
```

Expected response:
```json
{
  "status": "success",
  "message": "Job queued for upscaling",
  "input": "/mnt/media/movies/sample.mkv",
  "output": "/data/upscaled/sample.ts"
}
```

### Test from Jellyfin

1. Start the watchdog in a terminal: `python3 scripts/watchdog.py`
2. Play any movie or episode in Jellyfin
3. Watch the watchdog terminal for output

Expected watchdog output:
```
================================================================================
Webhook received!
Extracted file path: /mnt/media/movies/sample.mkv
✓ File exists: /mnt/media/movies/sample.mkv
✓ Job added to queue
✓ Upscale job queued successfully!
================================================================================
```

## Troubleshooting

### Problem: Empty Template Variables ⚠️ MOST COMMON ISSUE

**Symptoms:**
- Watchdog logs show: `"Path": "", "Name": "", "Type": ""`
- Error: "Webhook template variables are empty"
- Webhook returns 400 error
- Error message in logs: "Item.Path is empty string - Jellyfin not filling template"

**Example from logs:**
```
"Item": {
  "Path": "",
  "Name": "",
  "Type": ""
}
ERROR: No file path found in webhook payload!
Template variables are EMPTY ({{Item.Path}} = '')
```

**Root Cause:**
Jellyfin isn't filling in the template variables `{{Item.Path}}`, `{{Item.Name}}`, etc.

**Common Causes:**

1. **❌ Wrong Notification Type** - "Playback Start" is NOT checked
   - Without this, Jellyfin doesn't have playback context to fill variables

2. **❌ Wrong Item Type** - "Movie" or "Episode" are NOT checked
   - Without this, Jellyfin ignores video file playback events

3. **❌ Template syntax error** - Using `{{{Item.Path}}}` (triple braces)
   - Should be: `{{Item.Path}}` (double braces)

4. **❌ Webhook plugin version issue** - Old plugin version
   - Update to latest Jellyfin webhook plugin

**Solution:**

**Step 1:** Go to Jellyfin Dashboard → Plugins → Webhooks

**Step 2:** Edit your "SRGAN Upscaler" webhook

**Step 3:** Verify these checkboxes are CHECKED:

```
Notification Type:  ⚠️ MUST CHECK THIS
☑ Playback Start    ← CHECK THIS BOX!
☐ Playback Stop     ← Leave unchecked
☐ Other types...    ← Leave unchecked

Item Type:  ⚠️ MUST CHECK BOTH
☑ Movie             ← CHECK THIS BOX!
☑ Episode           ← CHECK THIS BOX!
☐ Audio             ← Leave unchecked
☐ Other types...    ← Leave unchecked
```

**Step 4:** Verify Template uses **double braces** (not triple):

✅ **CORRECT:**
```json
{
  "Item": {
    "Path": "{{Item.Path}}",
    "Name": "{{Item.Name}}",
    "Type": "{{Item.Type}}"
  }
}
```

❌ **WRONG:**
```json
{
  "Item": {
    "Path": "{{{Item.Path}}}",
    "Name": "{{{Item.Name}}}",
    "Type": "{{{Item.Type}}}"
  }
}
```

**Step 5:** Click **Save**

**Step 6:** Test by playing a video in Jellyfin

**Verification:**

After fixing, check watchdog logs:

```bash
# Watch logs
sudo journalctl -u srgan-watchdog -f

# Or if running manually, check terminal output
```

**Before (BROKEN):**
```
Webhook received!
Full payload: {
  "Item": {
    "Path": "",          ← EMPTY!
    "Name": "",          ← EMPTY!
    "Type": ""           ← EMPTY!
  }
}
ERROR: No file path found in webhook payload!
```

**After (FIXED):**
```
Webhook received!
Full payload: {
  "Item": {
    "Path": "/mnt/media/movies/film.mkv",    ← FILLED!
    "Name": "Film",                           ← FILLED!
    "Type": "Movie"                           ← FILLED!
  }
}
✓ File exists: /mnt/media/movies/film.mkv
```

**Quick test without playing video:**
```bash
# Test with correct payload
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item":{"Path":"/mnt/media/test.mkv"}}'

# Should return file not found (that's OK - it parsed the path!)
```

---

### Problem: No webhook received when playing video

**Check:**
1. Is watchdog running? `curl http://localhost:5000/health`
2. Is webhook enabled in Jellyfin?
3. Is the webhook URL correct? (use server IP, not localhost if Jellyfin is on different machine)
4. Check Jellyfin webhook logs: Dashboard → Plugins → Webhooks

### Problem: "Item.Path not found"

**Solution:**
- Verify template has `{{Item.Path}}` with double curly braces
- Check Request Content Type is `application/json`
- Try the minimal template:
  ```json
  {
    "Item": {
      "Path": "{{Item.Path}}"
    }
  }
  ```

### Problem: "File does not exist"

**Diagnosis:**
```bash
# Check what path Jellyfin reports (from watchdog logs)
# Then verify that path exists on the watchdog host
ls -lh /path/from/webhook
```

**Common causes:**
1. **Path mismatch**: Jellyfin path doesn't match host filesystem
   - If Jellyfin in Docker: Check volume mounts
   - Example: Jellyfin sees `/media/movies` but host has `/mnt/media/movies`

2. **NFS mount not accessible**: Check mount is active
   ```bash
   mount | grep /mnt/media
   ```

3. **Permissions**: File exists but not readable
   ```bash
   ls -lh /path/to/file.mkv
   ```

**Solution for path mismatch:**

Edit `scripts/watchdog.py` and add path translation after line 12:
```python
input_file = data.get("Item", {}).get("Path")

# Add path translation here:
input_file = input_file.replace("/media/", "/mnt/media/")  # Adjust as needed
```

### Problem: Container not starting

**Check:**
```bash
# Is container built?
docker images | grep srgan

# Build if needed
docker compose build srgan-upscaler

# Check logs
docker compose logs srgan-upscaler
```

### Problem: No output file created

**Check container logs:**
```bash
docker compose logs -f srgan-upscaler
```

Look for ffmpeg errors or GPU access issues.

## Environment Variables

### For Watchdog (on host)

```bash
# Output directory (default: /data/upscaled)
export UPSCALED_DIR=/mnt/media/upscaled

# Queue file location (default: ./cache/queue.jsonl)
export SRGAN_QUEUE_FILE=/home/user/srgan/cache/queue.jsonl
```

### For Container (in docker-compose.yml)

```yaml
environment:
  - SRGAN_QUEUE_FILE=/app/cache/queue.jsonl
  - UPSCALED_DIR=/data/upscaled
  - SRGAN_FFMPEG_ENCODER=hevc_nvenc  # Use NVIDIA GPU encoding
```

## Complete Working Example

### Scenario: Local server with NFS mount

**System:**
- Jellyfin on same host as watchdog
- Media on NFS mount at `/mnt/media`
- Output to `/mnt/media/upscaled`

**Configuration:**

1. **Create output directory:**
   ```bash
   mkdir -p /mnt/media/upscaled
   ```

2. **Set environment:**
   ```bash
   export UPSCALED_DIR=/mnt/media/upscaled
   ```

3. **Start watchdog:**
   ```bash
   python3 scripts/watchdog.py
   ```

4. **Jellyfin webhook URL:**
   ```
   http://localhost:5000/upscale-trigger
   ```

5. **Template:**
   ```json
   {
     "Item": {
       "Path": "{{Item.Path}}"
     }
   }
   ```

6. **Test:**
   ```bash
   python3 scripts/test_webhook.py --test-file /mnt/media/movies/test.mkv
   ```

## Getting Help

1. **Run diagnostics:**
   ```bash
   python3 scripts/verify_setup.py
   python3 scripts/test_webhook.py
   ```

2. **Check logs:**
   ```bash
   # Watchdog logs (if running in foreground)
   # Look at terminal output

   # Container logs
   docker compose logs srgan-upscaler

   # Jellyfin webhook logs
   # Dashboard → Plugins → Webhooks → View Logs
   ```

3. **Enable verbose logging:**
   Edit `scripts/watchdog.py`, line 10:
   ```python
   logging.basicConfig(level=logging.DEBUG)  # Change INFO to DEBUG
   ```

## Quick Reference Card

Print this and keep it handy:

```
╔═══════════════════════════════════════════════════════════════╗
║           SRGAN WEBHOOK QUICK REFERENCE                       ║
╠═══════════════════════════════════════════════════════════════╣
║ Start watchdog:    python3 scripts/watchdog.py               ║
║ Test webhook:      python3 scripts/test_webhook.py           ║
║ Verify setup:      python3 scripts/verify_setup.py           ║
║ Health check:      curl http://localhost:5000/health         ║
╠═══════════════════════════════════════════════════════════════╣
║ Jellyfin Webhook URL:                                         ║
║   http://YOUR_IP:5000/upscale-trigger                        ║
║                                                               ║
║ Required JSON field in template:                             ║
║   "Path": "{{Item.Path}}"                                    ║
║                                                               ║
║ Notification Type: ☑ Playback Start                          ║
║ Item Type: ☑ Movie  ☑ Episode                                ║
╚═══════════════════════════════════════════════════════════════╝
```

## See Also

- **[README.md](README.md)** - Project overview
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Installation guide
- **[SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)** - Service management
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Problem solving
- **[DOCUMENTATION.md](DOCUMENTATION.md)** - Complete documentation index
