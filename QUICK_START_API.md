# Quick Start - API-Based Watchdog

## ⚡ 5-Minute Setup

### 1️⃣ Create API Key (2 minutes)

```
Jellyfin Dashboard
  → Advanced
    → API Keys
      → Click "+"
        → Name: SRGAN Watchdog
          → Copy key
```

**Copy this key!** You'll need it in step 2.

---

### 2️⃣ Install & Configure (2 minutes)

```bash
ssh root@192.168.101.164
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

# Run installer (will prompt for API key)
sudo ./scripts/install_api_watchdog.sh
```

**Prompts:**
- **API key:** Paste the key from step 1
- **Jellyfin URL:** Press Enter for default (http://localhost:8096)

---

### 3️⃣ Configure Webhook (1 minute)

```
Jellyfin Dashboard
  → Plugins
    → Webhook
      → Add Generic Destination
```

**Settings:**
- **Webhook Url:** `http://localhost:5432/upscale-trigger`
- **Notification Type:** ✓ Playback Start
- **Item Type:** ✓ Movie, ✓ Episode
- **Template:** `{"event":"playback_start"}`

**Save!**

---

### 4️⃣ Test It!

**Terminal 1:**
```bash
sudo journalctl -u srgan-watchdog-api -f
```

**Terminal 2:** Play a video in Jellyfin

**Expected output:**
```
Webhook received!
Querying Jellyfin API for currently playing items...
Found playing item: Example Movie (/media/movies/Example.mkv)
✓ File exists: /media/movies/Example.mkv
✓ Streaming job added to queue
```

---

## ✅ Done!

Your upscaling pipeline is now using the **reliable Jellyfin API** instead of the problematic `{{Path}}` template variable.

---

## 🔍 Quick Commands

```bash
# Check status
sudo systemctl status srgan-watchdog-api

# View logs
sudo journalctl -u srgan-watchdog-api -f

# Test API connectivity
curl http://localhost:5432/status

# See what's currently playing
curl http://localhost:5432/playing

# Restart service
sudo systemctl restart srgan-watchdog-api
```

---

## 🐛 Troubleshooting

### Service won't start
```bash
# Check logs
sudo journalctl -u srgan-watchdog-api -n 50

# Common issues:
#   - API key invalid → Recreate in Jellyfin Dashboard
#   - Python requests not installed → sudo pip3 install requests
#   - Port 5432 in use → Check: sudo lsof -i :5432
```

### No file path in API response
```bash
# Test API manually
curl -H "X-Emby-Token: YOUR_API_KEY" http://localhost:8096/Sessions

# If Path is null, check:
#   - API key is from an ADMIN user
#   - Video is actually playing (not paused)
```

### Webhook not triggering
```bash
# Test webhook directly
curl -X POST http://localhost:5432/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"test":"manual"}'

# Should see in logs:
#   "Webhook received!"
#   "Querying Jellyfin API..."
```

---

## 📊 Comparison

| Method | Setup Time | Reliability | Maintenance |
|--------|-----------|-------------|-------------|
| **Template ({{Path}})** | 15 min | ❌ Often fails | ❌ Patch plugin |
| **API (/Sessions)** | 5 min | ✅ Always works | ✅ No patching |

---

## 🚀 Why API is Better

❌ **Template-based problems:**
- `{{Path}}` returns empty string
- Must patch webhook plugin
- Breaks after Jellyfin updates
- Hard to debug

✅ **API-based benefits:**
- Official Jellyfin API
- Always returns file path
- No plugin patching
- Easy to test

---

## 📖 Full Documentation

- **API_BASED_WATCHDOG.md** - Complete guide
- **ARCHITECTURE_SIMPLE.md** - How it works

---

**Questions?**
- Test API: `curl http://localhost:5432/status`
- View logs: `sudo journalctl -u srgan-watchdog-api -f`

**That's it! Reliable upscaling in 5 minutes!** 🎉
