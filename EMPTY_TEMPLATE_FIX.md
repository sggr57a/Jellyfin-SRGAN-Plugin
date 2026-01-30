# Empty Template Variables - Quick Fix Guide

## The Problem You're Seeing

Your watchdog logs show:

```
"Item": {
  "Path": "",
  "Name": "",
  "Type": ""
}
```

**All values are empty strings!** This means Jellyfin is sending the webhook, but not filling in the template variables.

---

## Why This Happens

Jellyfin webhook template variables like `{{Item.Path}}` only get filled when:

1. ✅ The correct **Notification Type** is selected ("Playback Start")
2. ✅ The correct **Item Type** is selected ("Movie" / "Episode")
3. ✅ Template syntax is correct (double braces, not triple)

If ANY of these are wrong → **Empty strings!**

---

## The Fix (2 Minutes)

### Step 1: Open Jellyfin Webhook Settings

1. Open Jellyfin Dashboard
2. Go to **Plugins** → **Webhooks**
3. Find "SRGAN Upscaler" (or your webhook name)
4. Click **Edit**

---

### Step 2: Check "Notification Type"

**CRITICAL:** You MUST check "Playback Start"

```
Notification Type:
☑ Playback Start     ← MUST BE CHECKED!
☐ Playback Stop
☐ User created
☐ Other types...
```

**Why:** Without "Playback Start", Jellyfin doesn't have the playback context (what file is being played), so `{{Item.Path}}` stays empty.

---

### Step 3: Check "Item Type"

**CRITICAL:** You MUST check "Movie" AND "Episode"

```
Item Type:
☑ Movie              ← CHECK THIS!
☑ Episode            ← CHECK THIS!
☐ Audio
☐ Book
☐ Other types...
```

**Why:** Without these, Jellyfin won't send webhooks when you play video files, so the webhook never fires for your content.

---

### Step 4: Verify Template Syntax

Make sure your template uses **DOUBLE braces** `{{ }}`, not triple `{{{ }}}`:

**✅ CORRECT (double braces):**
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

**❌ WRONG (triple braces):**
```json
{
  "Item": {
    "Path": "{{{Item.Path}}}",
    "Name": "{{{Item.Name}}}"
  }
}
```

**Why:** Triple braces `{{{ }}}` is for unescaped HTML in some templating engines. Jellyfin webhooks use **double braces** `{{ }}`.

---

### Step 5: Verify Request Content Type

While you're here, make sure this is set:

```
Request Content Type:
┌─────────────────────────────────┐
│ application/json          ▼    │
└─────────────────────────────────┘
```

---

### Step 6: Save and Test

1. Click **Save** at the bottom
2. Play a video in Jellyfin
3. Check the watchdog logs

---

## Verification

### Check Watchdog Logs

```bash
# If using systemd
sudo journalctl -u srgan-watchdog -f

# If running manually
# Check the terminal where you ran: python3 scripts/watchdog.py
```

### Before Fix (BROKEN)

```
================================================================================
Webhook received!
Content-Type: application/json
✓ Parsed as JSON from Content-Type header
Full payload: {
  "Item": {
    "Path": "",          ← EMPTY!
    "Name": "",
    "Type": ""
  },
  "User": {
    "Name": "YourUser"
  },
  "Event": "PlaybackStart"
}
Extracted file path:
ERROR: No file path found in webhook payload!

╔════════════════════════════════════════════════════════════╗
║  JELLYFIN WEBHOOK MISCONFIGURATION DETECTED                ║
╚════════════════════════════════════════════════════════════╝

Template variables are EMPTY ({{Item.Path}} = '')

COMMON CAUSES:
  1. Wrong Notification Type selected
     → Must be: Playback Start

  2. Wrong Item Type selected
     → Must be: Movie and/or Episode
```

### After Fix (WORKING)

```
================================================================================
Webhook received!
Content-Type: application/json
✓ Parsed as JSON from Content-Type header
Full payload: {
  "Item": {
    "Path": "/mnt/media/movies/sample.mkv",    ← FILLED!
    "Name": "Sample Movie",
    "Type": "Movie"
  },
  "User": {
    "Name": "YourUser"
  },
  "Event": "PlaybackStart"
}
Extracted file path: /mnt/media/movies/sample.mkv
✓ File exists: /mnt/media/movies/sample.mkv
Output directory: /data/upscaled
Creating output directory: /data/upscaled
✓ Streaming enabled
Creating HLS directory: /app/cache/hls/sample
Upscaling in streaming mode...
```

**Key difference:** `"Path": "/mnt/media/movies/sample.mkv"` instead of `"Path": ""`

---

## Common Scenarios

### Scenario 1: Only "Playback Stop" is Checked

**What happens:**
- Webhook fires when you STOP playing
- At that moment, `{{Item.Path}}` is empty (no file is playing)

**Fix:** Check "Playback Start" instead (or in addition to)

---

### Scenario 2: Only "Audio" is Checked in Item Type

**What happens:**
- Webhook only fires for music/audio files
- Your movies and TV shows are ignored

**Fix:** Check "Movie" and "Episode"

---

### Scenario 3: No Item Types Checked

**What happens:**
- Webhook never fires at all
- Nothing in the logs

**Fix:** Check "Movie" and "Episode"

---

### Scenario 4: Triple Braces in Template

**What happens:**
- Depends on Jellyfin version
- Usually results in empty strings or literal `{{{Item.Path}}}` in output

**Fix:** Use double braces: `{{Item.Path}}`

---

## Testing Without Playing a Video

You can test the endpoint is working with curl:

```bash
# This bypasses Jellyfin and tests the watchdog directly
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "Item": {
      "Path": "/mnt/media/movies/test.mkv",
      "Name": "Test",
      "Type": "Movie"
    },
    "User": {
      "Name": "TestUser"
    },
    "Event": "PlaybackStart"
  }'
```

**Expected response:**
```json
{
  "status": "error",
  "message": "File not found: /mnt/media/movies/test.mkv"
}
```

This is **GOOD!** It means:
- ✅ Webhook received the request
- ✅ Parsed JSON correctly
- ✅ Extracted the Path: `/mnt/media/movies/test.mkv`
- ✅ Tried to find the file (it doesn't exist, but that's OK for testing)

If you get this error, your webhook endpoint is working! The problem is just the Jellyfin configuration.

---

## The Watchdog Now Detects This Issue

The updated `watchdog.py` now automatically detects empty template variables and gives you this helpful error:

```
╔════════════════════════════════════════════════════════════╗
║  JELLYFIN WEBHOOK MISCONFIGURATION DETECTED                ║
╚════════════════════════════════════════════════════════════╝

Template variables are EMPTY ({{Item.Path}} = '')

COMMON CAUSES:
  1. Wrong Notification Type selected
     → Must be: Playback Start

  2. Wrong Item Type selected
     → Must be: Movie and/or Episode

  3. Template uses {{{}}} instead of {{}}
     → Correct: {{Item.Path}}
     → Wrong: {{{Item.Path}}}

  4. Jellyfin Webhook plugin version issue
     → Update to latest version

FIX: In Jellyfin Dashboard → Plugins → Webhooks:
  1. Edit your webhook
  2. Check 'Playback Start' under Notification Type
  3. Check 'Movie' and 'Episode' under Item Type
  4. Verify template uses {{Item.Path}} (double braces)
  5. Save and test by playing a video

See: WEBHOOK_SETUP.md for complete configuration
```

This error message tells you exactly what's wrong!

---

## Summary Checklist

Before closing this guide, verify:

- [ ] "Playback Start" is **CHECKED** in Notification Type
- [ ] "Movie" is **CHECKED** in Item Type
- [ ] "Episode" is **CHECKED** in Item Type
- [ ] Template uses `{{Item.Path}}` (double braces)
- [ ] Request Content Type is `application/json`
- [ ] You clicked **Save**
- [ ] You tested by playing a video
- [ ] Watchdog logs show a file path (not empty string)

---

## Still Not Working?

### Check Jellyfin Webhook Plugin Version

Old versions of the webhook plugin may have bugs. Update to the latest:

1. Dashboard → Plugins → Catalog
2. Find "Webhooks"
3. If update available, install it
4. Restart Jellyfin
5. Reconfigure webhook

### Check Jellyfin Logs

```bash
# Jellyfin logs location (typical)
sudo journalctl -u jellyfin -f

# Or check web UI
Dashboard → Logs
```

Look for webhook-related errors.

### Enable Webhook Debug Logging

Some webhook plugins have debug options. Check the webhook plugin settings page for a "debug" or "verbose logging" option.

---

## Quick Reference

| Setting | Required Value | Why |
|---------|---------------|-----|
| Notification Type | ☑ Playback Start | Provides playback context for `{{Item.Path}}` |
| Item Type | ☑ Movie, ☑ Episode | Tells Jellyfin to monitor video files |
| Template syntax | `{{Item.Path}}` | Double braces for Jellyfin templates |
| Request Content Type | `application/json` | Required for Flask JSON parsing |

**If ANY of these are wrong → webhook fails!**

---

**Complete setup guide:** `WEBHOOK_SETUP.md`
**Content-Type issues:** `WEBHOOK_CONTENT_TYPE_FIX.md`
**General troubleshooting:** `README.md` → Troubleshooting section
