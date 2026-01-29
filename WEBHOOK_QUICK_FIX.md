# Webhook Quick Fix - Empty Variables

## Your Error

```
"Item": {
  "Path": "",
  "Name": "",
  "Type": ""
}
```

## The Fix (30 seconds)

### 1. Open Jellyfin

Dashboard → Plugins → Webhooks → Click your webhook name

### 2. Check These Boxes

```
Notification Type:
☑ Playback Start     ← CHECK THIS!

Item Type:
☑ Movie              ← CHECK THIS!
☑ Episode            ← CHECK THIS!
```

### 3. Verify This Dropdown

```
Request Content Type:
┌──────────────────────────┐
│ application/json    ▼   │  ← Select this
└──────────────────────────┘
```

### 4. Verify Template

Should be:
```json
{
  "Item": {
    "Path": "{{Item.Path}}",
    "Name": "{{Item.Name}}",
    "Type": "{{Item.Type}}"
  }
}
```

Note: **Double braces** `{{}}` not triple `{{{}}}`

### 5. Save

Click **Save** button at bottom

### 6. Test

Play a video in Jellyfin

### 7. Check Logs

```bash
sudo journalctl -u srgan-watchdog -f
```

Should now show:
```
"Path": "/mnt/media/movies/film.mkv"  ← Not empty!
```

---

## Why This Happens

| Missing | Result |
|---------|--------|
| ❌ Not checked "Playback Start" | `{{Item.Path}}` stays empty |
| ❌ Not checked "Movie"/"Episode" | Webhook never fires for videos |
| ❌ Wrong template syntax `{{{}}}` | Variables stay empty |
| ❌ Wrong Content-Type | Can't parse JSON |

## Need More Help?

- Complete guide: `EMPTY_TEMPLATE_FIX.md`
- Full setup: `WEBHOOK_SETUP.md`
