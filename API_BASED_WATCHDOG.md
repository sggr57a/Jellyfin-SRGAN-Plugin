# API-Based Watchdog - More Reliable Solution

## Problem with {{Path}} Variable

The webhook plugin's `{{Path}}` template variable is unreliable:
- ❌ Often returns empty string
- ❌ Depends on webhook plugin internals
- ❌ May not work with all Jellyfin versions
- ❌ Requires patching webhook plugin

## Solution: Use Jellyfin API

Instead of relying on `{{Path}}`, we query Jellyfin's API directly:
- ✅ Official Jellyfin API endpoint
- ✅ Always returns file path for admin users
- ✅ No webhook plugin patching needed
- ✅ More reliable and maintainable

---

## How It Works

### Old Approach (Template-Based)
```
Jellyfin Webhook → Watchdog receives {"Path": "/media/file.mkv"}
                  → Watchdog uses path directly
```

**Problem:** `{"Path": ""}` (empty!)

### New Approach (API-Based)
```
Jellyfin Webhook → Watchdog receives notification (any payload)
                  → Watchdog queries: GET /Sessions
                  → Jellyfin returns currently playing items
                  → Extract file path from NowPlayingItem
                  → Queue upscaling job
```

**Benefit:** Path always available via API!

---

## Jellyfin API Response Example

When you query `GET /Sessions`, Jellyfin returns:

```json
[
  {
    "PlayState": {
      "PositionTicks": 123456789,
      "IsPaused": false,
      "IsMuted": false
    },
    "NowPlayingItem": {
      "Name": "Example Movie",
      "Id": "abc123...",
      "Type": "Movie",
      "Path": "/media/movies/Example.mkv",  ← FILE PATH HERE!
      "MediaSources": [
        {
          "Path": "/media/movies/Example.mkv",
          "Protocol": "File"
        }
      ]
    },
    "UserName": "admin",
    "Client": "Jellyfin Web",
    "Id": "session123..."
  }
]
```

The `NowPlayingItem.Path` contains the file path we need!

---

## Installation

### Step 1: Create Jellyfin API Key

1. Open Jellyfin Dashboard
2. Go to: **Dashboard → Advanced → API Keys**
3. Click **"+"** button
4. Application name: **SRGAN Watchdog**
5. Copy the generated key (looks like: `d4f8e9a7b2c1...`)

**Important:** Keep this key secure!

### Step 2: Install API-Based Watchdog

```bash
ssh root@192.168.101.164
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

# Run installation script
sudo ./scripts/install_api_watchdog.sh

# It will prompt for:
#   - Jellyfin API key (from step 1)
#   - Jellyfin URL (default: http://localhost:8096)
```

### Step 3: Configure Jellyfin Webhook

The webhook payload **doesn't matter** anymore, but you still need it to trigger the watchdog:

1. Dashboard → Plugins → Webhook
2. Add Generic Destination:
   - **Webhook Name:** SRGAN Trigger
   - **Webhook Url:** `http://localhost:5432/upscale-trigger`
   - **Notification Type:** ✓ Playback Start
   - **Item Type:** ✓ Movie, ✓ Episode
   - **Template:** (doesn't matter, but use):
     ```json
     {"event":"playback_start"}
     ```

**Note:** We don't need `{{Path}}` in the template! The watchdog queries the API for the path.

---

## Usage

### Start Service
```bash
sudo systemctl start srgan-watchdog-api
```

### Check Status
```bash
sudo systemctl status srgan-watchdog-api

# Should show:
# Active: active (running)
```

### View Logs
```bash
sudo journalctl -u srgan-watchdog-api -f

# Should show:
# SRGAN Watchdog - API-Based Version
# Jellyfin URL: http://localhost:8096
# API Key: ✓ Set
# Starting Flask server on 0.0.0.0:5432...
```

### Test Endpoints

#### Status Endpoint
```bash
curl http://localhost:5432/status

# Response:
{
  "status": "running",
  "jellyfin_url": "http://localhost:8096",
  "jellyfin_api_configured": true,
  "jellyfin_reachable": true,
  "queue_file": "./cache/queue.jsonl",
  "upscaled_dir": "/mnt/media/upscaled",
  "streaming_enabled": true
}
```

#### Sessions Endpoint (Debug)
```bash
curl http://localhost:5432/sessions

# Shows raw Jellyfin /Sessions response
```

#### Currently Playing Endpoint
```bash
curl http://localhost:5432/playing

# Response:
{
  "count": 1,
  "items": [
    {
      "path": "/media/movies/Example.mkv",
      "name": "Example Movie",
      "item_id": "abc123...",
      "item_type": "Movie",
      "user": "admin",
      "session_id": "session123...",
      "client": "Jellyfin Web"
    }
  ]
}
```

---

## Complete Test

### Terminal 1: Monitor Logs
```bash
sudo journalctl -u srgan-watchdog-api -f
```

### Terminal 2: Test Manually
```bash
# Query API directly
curl http://localhost:5432/playing

# Should show currently playing items
```

### Terminal 3: Play Video in Jellyfin

1. Open Jellyfin web UI
2. Play any movie or episode
3. Watch Terminal 1 (logs)

**Expected output:**
```
Webhook received!
Querying Jellyfin API for currently playing items...
Found playing item: Example Movie (/media/movies/Example.mkv)
Found 1 playing item(s)
✓ File exists: /media/movies/Example.mkv
Streaming mode enabled
✓ Streaming job added to queue
  Input:      /media/movies/Example.mkv
  Output:     /mnt/media/upscaled/Example.ts
  HLS dir:    /mnt/media/upscaled/hls/Example/
  Item:       Example Movie
  User:       admin
Starting srgan-upscaler container...
✓ Docker compose command successful
```

---

## Configuration

### Environment Variables

Stored in: `/etc/default/srgan-watchdog-api`

```bash
# Jellyfin API Configuration
JELLYFIN_URL=http://localhost:8096
JELLYFIN_API_KEY=your_api_key_here

# Watchdog Configuration
UPSCALED_DIR=/mnt/media/upscaled
SRGAN_QUEUE_FILE=/root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl
ENABLE_HLS_STREAMING=1
HLS_SERVER_HOST=localhost
HLS_SERVER_PORT=8080
```

### Modify Configuration

```bash
# Edit configuration
sudo nano /etc/default/srgan-watchdog-api

# Restart service to apply
sudo systemctl restart srgan-watchdog-api
```

---

## Advantages Over Template-Based

| Feature | Template-Based | API-Based |
|---------|---------------|-----------|
| **Reliability** | ❌ {{Path}} often empty | ✅ API always works |
| **Setup** | ❌ Patch webhook plugin | ✅ Just need API key |
| **Maintenance** | ❌ Re-patch after updates | ✅ Uses official API |
| **Dependencies** | ❌ Custom webhook build | ✅ Standard Jellyfin |
| **Debugging** | ❌ Hard to troubleshoot | ✅ Easy to test API |
| **Multi-session** | ❌ One webhook per play | ✅ Can detect all sessions |

---

## API Permissions

**Important:** The Jellyfin API key must have admin permissions to access file paths.

By default:
- ✅ Admin users can see `Path` in API responses
- ❌ Regular users cannot see `Path` (security)

If you see:
```json
{
  "NowPlayingItem": {
    "Name": "Movie",
    "Path": null  ← Missing!
  }
}
```

**Solution:** Use an API key from an admin account.

---

## Debugging

### Problem: API Key Not Working

```bash
# Test API key manually
JELLYFIN_URL="http://localhost:8096"
API_KEY="your_key_here"

curl -H "X-Emby-Token: ${API_KEY}" "${JELLYFIN_URL}/Sessions"

# Should return JSON array
# If error, API key is invalid
```

### Problem: Path is Null in API Response

```bash
# Check if you're using admin API key
curl -H "X-Emby-Token: ${API_KEY}" "${JELLYFIN_URL}/Users/Me"

# Should show:
{
  "Policy": {
    "IsAdministrator": true  ← Must be true!
  }
}
```

### Problem: No Currently Playing Items

```bash
# While video is playing:
curl http://localhost:5432/playing

# Should show items
# If empty, check:
#   1. Video is actually playing (not paused)
#   2. Jellyfin is reachable
#   3. API key is valid
```

### Problem: Webhook Not Triggering

```bash
# Check webhook configuration
grep "http://localhost:5432" /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml

# Should find the URL
# If not, webhook not configured
```

---

## Migration from Template-Based

If you're currently using the template-based watchdog:

```bash
# 1. Stop old watchdog
sudo systemctl stop srgan-watchdog
sudo systemctl disable srgan-watchdog

# 2. Install API-based watchdog
sudo ./scripts/install_api_watchdog.sh

# 3. Update webhook configuration (remove {{Path}})
# Dashboard → Plugins → Webhook
# Edit template to just: {"event":"playback_start"}

# 4. Test
# Play video, check logs:
sudo journalctl -u srgan-watchdog-api -f
```

**Old files remain** (for backup):
- `/etc/systemd/system/srgan-watchdog.service` (old service)
- `scripts/watchdog.py` (old template-based version)

You can delete them after confirming API version works.

---

## Architecture Comparison

### Template-Based Flow
```
Jellyfin → Webhook Plugin fills {{Path}}
         → POST to Watchdog with {"Path": "/media/file.mkv"}
         → Watchdog uses path
         → Queue job
```

### API-Based Flow
```
Jellyfin → Webhook Plugin sends notification
         → POST to Watchdog (payload ignored)
         → Watchdog queries GET /Sessions
         → Jellyfin returns currently playing items with paths
         → Extract path from NowPlayingItem.Path
         → Queue job
```

---

## Advanced: Polling Mode

You can also run the API watchdog in **polling mode** (no webhook needed):

```python
# Poll Jellyfin API every 5 seconds
while True:
    items = extract_playing_items()
    for item in items:
        if not is_recently_processed(item['item_id']):
            queue_upscaling_job(item)
    time.sleep(5)
```

This would eliminate the webhook entirely, but uses more resources.

---

## Summary

**The API-based approach is more reliable:**

1. ✅ No need to patch webhook plugin
2. ✅ No dependency on {{Path}} template variable
3. ✅ Uses official Jellyfin API
4. ✅ Easy to debug and test
5. ✅ Works with all Jellyfin versions

**Setup:**
```bash
# 1. Create API key in Jellyfin Dashboard
# 2. Run: sudo ./scripts/install_api_watchdog.sh
# 3. Configure webhook to POST to http://localhost:5432/upscale-trigger
# 4. Play video, check logs
```

**That's it! More reliable upscaling with Jellyfin API!** 🚀
