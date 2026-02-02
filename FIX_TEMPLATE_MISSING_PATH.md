# URGENT FIX: Template Does NOT Include {{Path}}

## Problem

Webhook configuration template is missing the `{{Path}}` variable.

## Immediate Fix - Run This NOW

```bash
ssh root@192.168.101.164

cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

# Fix the template
sudo ./scripts/fix_webhook_template_now.sh
```

## What This Does

1. ✅ Checks if `{{Path}}` is in webhook configuration
2. ✅ Backs up current configuration
3. ✅ Regenerates configuration with `{{Path}}`
4. ✅ Verifies `{{Path}}` is now present
5. ✅ Restarts Jellyfin to apply changes
6. ✅ Shows decoded template for verification

## Expected Output

```bash
==========================================================================
FIXING WEBHOOK TEMPLATE - Adding {{Path}} Variable
==========================================================================

Checking current webhook configuration...
✗ Template does NOT include {{Path}}

Backed up to: /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml.backup.20260201_153045

Reconfiguring webhook with {{Path}} variable...
✓ Webhook reconfigured successfully

Verifying {{Path}} is now in template...
✓✓✓ SUCCESS! {{Path}} is now in the template! ✓✓✓

Template content (decoded):
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

Restarting Jellyfin to apply changes...
✓ Jellyfin restarted successfully

==========================================================================
TEMPLATE FIXED!
==========================================================================
```

## Manual Alternative

If the script doesn't work, configure manually:

```bash
sudo python3 /root/Jellyfin-SRGAN-Plugin/scripts/configure_webhook.py http://localhost:5000

sudo systemctl restart jellyfin
```

## Verify Template Has {{Path}}

```bash
# Check if Path is in the template
grep "{{Path}}" /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml

# Should return a line with {{Path}} in it
```

## Decode and View Template

```bash
# Extract and decode the template
grep "<Template>" /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml | \
  sed 's/<Template>//;s/<\/Template>//' | \
  base64 -d | \
  python3 -m json.tool

# Should show:
# {
#   "Path": "{{Path}}",
#   "Name": "{{Name}}",
#   ...
# }
```

## Test After Fix

```bash
# Terminal 1: Monitor logs
tail -f /var/log/srgan-watchdog.log

# Terminal 2: Play video in Jellyfin
```

**Expected:**
```json
{
  "Path": "/media/movies/Example.mkv",  ← SHOULD APPEAR!
  "Name": "Example Movie",
  "ItemType": "Movie"
}
```

## Why Template Was Missing {{Path}}

Possible reasons:
1. Webhook was installed from catalog but never configured with our script
2. Configuration was reset by Jellyfin update
3. Manual changes in Jellyfin Dashboard removed it
4. Configuration file was corrupted

## Complete Configuration Check

After fixing template, verify webhook in Jellyfin Dashboard:

1. Open: http://192.168.101.164:8096
2. Go to: Dashboard → Plugins → Webhook
3. Check webhook named: **"SRGAN 4K Upscaler"**
4. Verify:
   - ✅ Webhook URL: `http://localhost:5000/upscale-trigger`
   - ✅ Notification Type: **PlaybackStart** (checked)
   - ✅ Item Types: **Movies** and **Episodes** (checked)
   - ✅ Template includes: `{{Path}}`

## If Template Fix Fails

### Option 1: Manual Configuration in Jellyfin Dashboard

1. Open Jellyfin Dashboard → Plugins → Webhook
2. Click "Add Generic Destination"
3. Set:
   - **Webhook Name:** SRGAN 4K Upscaler
   - **Webhook URL:** http://localhost:5000/upscale-trigger
   - **Notification Type:** Check "Playback Start"
   - **Item Type:** Check "Movies" and "Episodes"
   - **Template:** Paste this:
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
4. Click Save
5. Restart Jellyfin

### Option 2: Delete and Recreate Configuration

```bash
# Backup first
sudo cp /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml \
        /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml.old

# Delete current config
sudo rm /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml

# Recreate with Path
sudo python3 /root/Jellyfin-SRGAN-Plugin/scripts/configure_webhook.py http://localhost:5000

# Restart
sudo systemctl restart jellyfin
```

## Success Verification

After running the fix, verify:

```bash
# 1. Check template has Path
grep "{{Path}}" /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml && echo "✓ Path in template"

# 2. Check Jellyfin is running
systemctl is-active jellyfin && echo "✓ Jellyfin running"

# 3. Test with playback
tail -f /var/log/srgan-watchdog.log
# Play video and check for Path in logs
```

## Quick Reference

```bash
# Fix template
sudo ./scripts/fix_webhook_template_now.sh

# Verify fix
grep "{{Path}}" /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml

# Test
tail -f /var/log/srgan-watchdog.log
# Play video in Jellyfin
```

---

**Run the fix script and {{Path}} will be in the template!** 🚀
