# 🚀 Run This On Your Server - Quick Fix

## SSH to Server
```bash
ssh root@192.168.101.164
# Password: den1ed
```

## Fix {{Path}} Empty Issue

### Option 1: Comprehensive Diagnostic & Fix (Recommended)
```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
sudo ./scripts/fix_webhook_path_complete.sh
```

**This script:**
- ✅ Checks every step
- ✅ Fixes problems automatically
- ✅ Verifies patch applied
- ✅ Rebuilds and installs
- ✅ Shows clear success/failure

### Option 2: Full Installation
```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
sudo ./scripts/install_all.sh
```

**Now includes:**
- ✅ Automatic webhook source setup
- ✅ Automatic Path patch
- ✅ Final verification report

## Test It Works

### Start Monitoring
```bash
tail -f /var/log/srgan-watchdog.log
```

### Play Video
Open Jellyfin browser, play any movie.

### Expected Result
```json
{
  "Path": "/media/movies/Example.mkv",  ← Should have path!
  "Name": "Example Movie",
  "ItemType": "Movie"
}
```

## If Still Empty

### Check Patch Applied
```bash
grep '"Path".*item\.Path' /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs

# Should show:
# dataObject["Path"] = item.Path;
```

### Manually Reconfigure
```bash
sudo python3 /root/Jellyfin-SRGAN-Plugin/scripts/configure_webhook.py http://localhost:5000
sudo systemctl restart jellyfin
```

### Check Webhook in Jellyfin
1. Open: http://192.168.101.164:8096
2. Dashboard → Plugins → Webhook
3. Verify "SRGAN 4K Upscaler" webhook exists
4. Check template includes {{Path}}

## Documentation

- **FIX_PATH_EMPTY_FINAL.md** - Complete troubleshooting guide
- **COMPLETE_INSTALLATION_FIXED.md** - Full explanation of fixes
- **QUICK_FIX_GUIDE.md** - Quick reference

---

**That's it! Pull latest code and run fix script!** 🎉
