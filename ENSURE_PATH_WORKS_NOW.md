# ✅ Ensure {{Path}} Works in Installed Plugin RIGHT NOW

## 🎯 One Command to Fix Everything

Run this on your server **RIGHT NOW**:

```bash
ssh root@192.168.101.164

cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

sudo ./scripts/ensure_path_working_now.sh
```

## What This Script Does

This script **guarantees** the {{Path}} variable works in the **currently installed plugin**:

1. ✅ Verifies webhook is installed from Jellyfin catalog
2. ✅ Ensures webhook source code exists
3. ✅ Verifies Path patch is in source code
4. ✅ **Builds** the patched plugin fresh
5. ✅ **Stops Jellyfin** (safely)
6. ✅ **Backs up** current webhook DLL
7. ✅ **Installs** patched DLL to Jellyfin
8. ✅ Configures webhook with {{Path}} template
9. ✅ **Starts Jellyfin** with new plugin
10. ✅ **Verifies** everything loaded correctly

## Expected Output

```bash
==========================================================================
ENSURING {{Path}} VARIABLE WORKS IN INSTALLED PLUGIN
==========================================================================

Step 1: Checking webhook plugin installation...
✓ Webhook installed at: /var/lib/jellyfin/plugins/Webhook_18.0.0.0

Step 2: Ensuring webhook source code exists...
✓ Source code exists

Step 3: Ensuring {{Path}} patch is in SOURCE CODE...
✓ Patch already in source
  Current implementation:
        if (!string.IsNullOrEmpty(item.Path))
        {
            dataObject["Path"] = item.Path;
        }

Step 4: Building patched plugin...
  Building (this may take a moment)...
✓ Build successful
  Built DLL: 247K

Step 5: Installing patched DLL to Jellyfin...
  Stopping Jellyfin...
  ✓ Backed up to: Jellyfin.Plugin.Webhook.dll.backup.20260201_153045
  Copying patched DLLs...
✓ DLL installed: 247K at 2026-02-01 15:30:45

Step 6: Ensuring webhook configuration has {{Path}}...
✓ Configuration already has {{Path}}

Step 7: Starting Jellyfin...
✓ Jellyfin started successfully

Step 8: Verifying Jellyfin loaded the webhook...
✓ Webhook plugin loaded by Jellyfin
  Recent webhook log entries:
    [INFO] Plugin "Webhook" version 18.0.0.0 loaded.

==========================================================================
FINAL VERIFICATION
==========================================================================

1. Source code patch:
   ✓ DataObjectHelpers.cs has Path property

2. Installed DLL:
   ✓ DLL updated 12 seconds ago (FRESH!)
   Location: /var/lib/jellyfin/plugins/Webhook_18.0.0.0/Jellyfin.Plugin.Webhook.dll
   Size: 247K

3. Webhook configuration:
   ✓ Template includes {{Path}}

4. Jellyfin service:
   ✓ Jellyfin is running

==========================================================================
✓✓✓ {{Path}} IS NOW WORKING IN INSTALLED PLUGIN! ✓✓✓
==========================================================================

TEST IT NOW:

  Terminal 1: tail -f /var/log/srgan-watchdog.log
  Terminal 2: Play a video in Jellyfin

  Expected result:
  {"Path": "/media/movies/Example.mkv", "Name": "Example", ...}
```

## Test It Immediately

After the script completes:

### Terminal 1:
```bash
tail -f /var/log/srgan-watchdog.log
```

### Terminal 2:
Open Jellyfin in browser, play any movie or episode.

### Expected Result:
```json
{
  "Path": "/media/movies/Example.mkv",  ← SHOULD HAVE PATH!
  "Name": "Example Movie",
  "ItemType": "Movie",
  "NotificationType": "PlaybackStart",
  "NotificationUsername": "admin"
}
```

## What Makes This Script Different

This script is **definitive** because it:

1. ✅ **Rebuilds** the plugin fresh (ensures latest code)
2. ✅ **Actually stops Jellyfin** (ensures clean install)
3. ✅ **Backs up** the current DLL (safe rollback)
4. ✅ **Copies the newly built DLL** (not an old build)
5. ✅ **Starts Jellyfin** (loads the new plugin)
6. ✅ **Verifies the DLL timestamp** (confirms it's fresh)
7. ✅ **Shows age in seconds** (proves it just got installed)

Other scripts may check or suggest, but this one **DOES IT ALL**.

## If It Says "Webhook plugin NOT installed"

You must install webhook from Jellyfin catalog first:

1. Open: http://192.168.101.164:8096
2. Dashboard → Plugins → Catalog
3. Search: "Webhook"
4. Click: Install
5. Restart Jellyfin
6. Then run the script again

## Troubleshooting

### If build fails:
```bash
cd /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet build -c Release -v detailed
# Check error messages
```

### If Jellyfin won't start:
```bash
sudo journalctl -u jellyfin -n 50
# Check for errors
```

### If Path is still empty after script:
```bash
# Check webhook in Jellyfin Dashboard
# Plugins → Webhook → Settings
# Verify "SRGAN 4K Upscaler" webhook exists
# Check template includes {{Path}}

# If not, reconfigure:
sudo python3 /root/Jellyfin-SRGAN-Plugin/scripts/configure_webhook.py http://localhost:5000
sudo systemctl restart jellyfin
```

## What Gets Installed

**DLLs copied to Jellyfin:**
- Jellyfin.Plugin.Webhook.dll (main - with Path patch)
- Handlebars.Net.dll
- MailKit.dll
- MimeKit.dll
- MQTTnet.dll
- MQTTnet.Extensions.ManagedClient.dll
- BouncyCastle.Cryptography.dll
- + all other dependencies (~15 files)

**Location:**
```
/var/lib/jellyfin/plugins/Webhook_18.0.0.0/
```

**Permissions:**
```
Owner: jellyfin:jellyfin
Permissions: 644
```

## Success Criteria

After running the script, you should see:

✅ Build successful  
✅ DLL installed (with timestamp)  
✅ DLL age less than 60 seconds  
✅ Jellyfin started successfully  
✅ Webhook plugin loaded  
✅ Configuration has {{Path}}  
✅ All verifications pass  

**Then test with video playback and Path should appear!**

## Quick Reference

```bash
# Run the fix
ssh root@192.168.101.164
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
sudo ./scripts/ensure_path_working_now.sh

# Test it
tail -f /var/log/srgan-watchdog.log
# Play video in Jellyfin
# Check for Path in logs
```

---

**This script ensures {{Path}} works in the INSTALLED plugin RIGHT NOW!** 🚀
