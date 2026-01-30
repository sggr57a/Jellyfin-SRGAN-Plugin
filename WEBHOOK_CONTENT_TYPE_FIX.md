# Webhook Content-Type Fix

## Problem

Webhook fails with error: **"Invalid JSON payload"** or **"Failed to parse request body as JSON"**

## Root Cause

The Jellyfin webhook is not sending the correct `Content-Type` header. The watchdog endpoint requires `Content-Type: application/json` to parse the request body as JSON.

## Solution

### Quick Fix (3 steps)

1. **Open Jellyfin Dashboard** → **Plugins** → **Webhooks**

2. **Edit your webhook** and find **Request Content Type**

3. **Select:** `application/json`

```
┌─────────────────────────────────────────┐
│ Request Content Type:                   │
│ ┌─────────────────────────────────────┐ │
│ │ application/json              ▼    │ │  ← Select this!
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

4. **Click Save**

5. **Test** by playing a video

---

## What Was Changed in the Code

### Watchdog.py Enhanced Error Handling

The webhook endpoint (`watchdog.py`) has been updated to:

**1. Log Content-Type for debugging:**
```python
logger.info(f"Content-Type: {request.content_type}")
```

**2. Try to parse JSON even if Content-Type is wrong:**
```python
if request.is_json:
    data = request.json
else:
    # Try to parse body as JSON even if content-type is wrong
    try:
        data = json.loads(request.data.decode('utf-8'))
        logger.warning("Content-Type is wrong but body is valid JSON")
    except:
        return error with clear message
```

**3. Return helpful error message:**
```json
{
  "status": "error",
  "message": "Invalid JSON payload. Please set Content-Type: application/json",
  "content_type_received": "text/plain",
  "expected": "application/json"
}
```

---

## Complete Webhook Configuration

### Required Settings

| Setting | Value | Notes |
|---------|-------|-------|
| **Webhook Name** | SRGAN Upscaler | Any name you want |
| **Webhook URL** | `http://SERVER_IP:5000/upscale-trigger` | Replace SERVER_IP |
| **Request Content Type** | `application/json` | ⚠️ CRITICAL |
| **Notification Type** | Playback Start | Check this box |
| **Item Type** | Movie, Episode | Check both |

### JSON Template

Paste this in the **Template** field:

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

**Important:**
- Use **double curly braces** `{{ }}`
- The `Path` field is **REQUIRED**
- Must be valid JSON (comma after each field except the last)

---

## Verification

### Check Watchdog Logs

After saving the configuration, check the logs when you play a video:

```bash
# If using systemd
sudo journalctl -u srgan-watchdog -f

# If running manually
# Check terminal output
```

**Good output (correct Content-Type):**
```
Webhook received!
Content-Type: application/json ✓
✓ Parsed as JSON from Content-Type header
Full payload: {
  "Item": {
    "Path": "/mnt/media/movies/film.mkv"
  }
}
✓ File exists: /mnt/media/movies/film.mkv
```

**Bad output (wrong Content-Type):**
```
Webhook received!
Content-Type: text/plain ✗
⚠️ Content-Type is 'text/plain' but body is valid JSON
   Please set Content-Type: application/json in Jellyfin webhook
```

**Worst output (can't parse at all):**
```
Webhook received!
Content-Type: application/x-www-form-urlencoded ✗
ERROR: Failed to parse request body as JSON
```

---

## Testing

### Test with curl

```bash
# Good request (correct Content-Type)
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item":{"Path":"/mnt/media/test.mkv"}}'

# Should return:
# {"status": "error", "message": "File not found..."}
# (File not found is OK - means it parsed the JSON!)

# Bad request (wrong Content-Type)
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: text/plain" \
  -d '{"Item":{"Path":"/mnt/media/test.mkv"}}'

# Should return:
# {"status": "error", "message": "Invalid JSON payload..."}
```

### Test with Python script

```bash
python3 scripts/test_webhook.py
```

This script tests the webhook with correct Content-Type automatically.

---

## Why This Matters

### Flask Request Parsing

Flask's `request.json` only works when:
1. Content-Type header is `application/json`
2. Body contains valid JSON

If Content-Type is wrong, Flask won't parse the body as JSON automatically.

### What Each Content-Type Means

| Content-Type | Description | Works? |
|--------------|-------------|--------|
| `application/json` | JSON data | ✅ YES |
| `application/x-www-form-urlencoded` | Form data (key=value&key2=value2) | ❌ NO |
| `text/plain` | Plain text | ❌ NO |
| `multipart/form-data` | File upload format | ❌ NO |

**Only `application/json` works for this webhook!**

---

## Common Mistakes

### ❌ Mistake 1: Leaving Content-Type blank

**What happens:**
- Jellyfin sends Content-Type: `text/plain` (default)
- Watchdog can't parse JSON
- Returns error

**Fix:** Select `application/json` from dropdown

---

### ❌ Mistake 2: Wrong template format

**What happens:**
- JSON is invalid (missing commas, wrong brackets)
- Watchdog can't parse even with correct Content-Type

**Fix:** Copy template exactly from documentation

---

### ❌ Mistake 3: Not saving after changes

**What happens:**
- Settings look correct in UI
- Old settings still active

**Fix:** Always click **Save** button

---

## Fallback Behavior

### Current Implementation

The watchdog now **tries to parse JSON even if Content-Type is wrong**:

1. Check if `Content-Type: application/json` → Parse with `request.json`
2. If not, try to parse body manually → Success with warning
3. If parsing fails → Return clear error message

This means:
- ✅ Webhook still works if you forget to set Content-Type
- ⚠️ You'll see warning in logs
- ✅ Clear error message if body isn't valid JSON

**But please set Content-Type correctly!** The fallback is just for tolerance.

---

## Troubleshooting Decision Tree

```
Webhook not working?
    │
    ├─ Check watchdog logs
    │   │
    │   ├─ "Content-Type: application/json" → Content-Type is correct ✓
    │   │                                      Problem is elsewhere
    │   │
    │   └─ "Content-Type: text/plain" → Go to Jellyfin
    │                                    Set Content-Type to application/json
    │
    ├─ Still not working?
    │   │
    │   ├─ Check "Full payload" in logs
    │   │   │
    │   │   ├─ Shows JSON → JSON is valid ✓
    │   │   │               Check Item.Path exists
    │   │   │
    │   │   └─ Parse error → Fix JSON template
    │   │
    │   └─ No logs at all → Webhook not reaching server
    │                        Check URL, firewall, network
```

---

## Summary

### The Fix

**Before:**
```
Content-Type: text/plain ✗
→ Webhook fails
→ Error: "Invalid JSON payload"
```

**After:**
```
Content-Type: application/json ✓
→ Webhook works
→ Success: Job queued
```

### What Changed

1. **Watchdog enhanced:**
   - Logs Content-Type for debugging
   - Tries to parse even if Content-Type wrong
   - Returns helpful error messages

2. **Documentation updated:**
   - Content-Type setting highlighted
   - Troubleshooting section added
   - Visual guide included

### Action Required

**Just set one dropdown in Jellyfin:**

```
Request Content Type: application/json
```

**That's it!**

---

**For complete webhook setup guide, see:** `WEBHOOK_SETUP.md`
