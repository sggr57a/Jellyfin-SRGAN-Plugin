# Complete Fix - Template + Volume Mounts

## Two Issues Found

### Issue 1: ❌ Template Does NOT Include {{Path}}
The webhook configuration is missing the `{{Path}}` variable.

### Issue 2: ❌ Docker Container Cannot Find Input File
The container doesn't have access to Jellyfin's media files.

## Complete Fix - Run These Commands

```bash
ssh root@192.168.101.164
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

# Fix 1: Add {{Path}} to webhook template
sudo ./scripts/fix_webhook_template_now.sh

# Fix 2: Diagnose volume mount issue
./scripts/diagnose_path_issue.sh

# Fix 3: Auto-fix volume mounts
sudo ./scripts/fix_docker_volumes.sh

# Or use the all-in-one comprehensive fix:
sudo ./scripts/fix_webhook_path_complete.sh
```

## What Each Script Does

### 1. `fix_webhook_template_now.sh`
- ✅ Checks if `{{Path}}` is in template
- ✅ Backs up current config
- ✅ Regenerates webhook config with `{{Path}}`
- ✅ Restarts Jellyfin
- ✅ Verifies `{{Path}}` is now present

### 2. `diagnose_path_issue.sh`
- ✅ Shows what path webhook is sending
- ✅ Shows current Docker volume mounts
- ✅ Tests what paths container can access
- ✅ Identifies Jellyfin media directories
- ✅ Provides specific fix commands

### 3. `fix_docker_volumes.sh`
- ✅ Auto-detects media directories
- ✅ Updates docker-compose.yml
- ✅ Recreates container
- ✅ Tests file accessibility

## Expected Results

### After fix_webhook_template_now.sh:
```
✓✓✓ SUCCESS! {{Path}} is now in the template! ✓✓✓

Template content (decoded):
{
  "Path": "{{Path}}",    ← NOW PRESENT!
  "Name": "{{Name}}",
  ...
}
```

### After fix_docker_volumes.sh:
```
✓ Docker Volumes Fixed!

Volume mounts configured:
  /media → /media (read-only)
  /mnt/media → /mnt/media (read-only)
  /mnt/media/upscaled → /data/upscaled (read-write)

Testing: /media
  ✓ Accessible in container (245 video files)
```

## Complete Test

After running all fixes:

### Terminal 1: Monitor Logs
```bash
tail -f /var/log/srgan-watchdog.log
```

### Terminal 2: Play Video
Open Jellyfin, play any video.

### Expected Output in Logs:
```
Webhook received!
Full payload: {
  "Path": "/media/movies/Example.mkv",  ← HAS PATH!
  "Name": "Example Movie",
  ...
}
Extracted file path: /media/movies/Example.mkv
✓ File accessible in container                 ← CONTAINER FINDS IT!
Starting upscaling...
```

**NOT:**
```
"Path": "",                          ← Empty
OR
ERROR: Input file not found          ← Container can't find it
```

## Updated docker-compose.yml

The latest version now includes common paths by default:

```yaml
  srgan-upscaler:
    volumes:
      # Media input paths
      - /media:/media:ro              # NEW - common path
      - /mnt/media:/mnt/media:ro      # UPDATED - better mount
      - /srv/media:/srv/media:ro      # NEW - common path
      
      # Output and working directories
      - /mnt/media/upscaled:/data/upscaled
      - ./cache:/app/cache
      - ./models:/app/models:ro
```

**If your media is at a different path, add it:**
```yaml
      - /your/custom/path:/your/custom/path:ro
```

## Verification Commands

### Check Template Has {{Path}}
```bash
grep "{{Path}}" /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml && echo "✓ Template OK"
```

### Check Volume Mounts
```bash
docker inspect srgan-upscaler | grep -A 20 Mounts

# Should show your media paths
```

### Test File Access
```bash
# Get a real file path from Jellyfin
JELLYFIN_FILE="/media/movies/Example.mkv"  # Replace with actual

# Check on host
test -f "${JELLYFIN_FILE}" && echo "✓ File exists on host"

# Check in container
docker compose -f /root/Jellyfin-SRGAN-Plugin/docker-compose.yml exec srgan-upscaler test -f "${JELLYFIN_FILE}" && echo "✓ File accessible in container" || echo "✗ NOT accessible"
```

## Common Scenarios

### Scenario 1: Jellyfin uses /media
```yaml
volumes:
  - /media:/media:ro
```

### Scenario 2: Jellyfin uses /mnt/media
```yaml
volumes:
  - /mnt/media:/mnt/media:ro
```

### Scenario 3: Multiple libraries
```yaml
volumes:
  - /media/movies:/media/movies:ro
  - /media/tv:/media/tv:ro
  - /mnt/storage:/mnt/storage:ro
```

### Scenario 4: NFS/SMB mounts
```yaml
volumes:
  - /mnt/nas/media:/mnt/nas/media:rslave  # Use rslave for network mounts
```

## After Fixing

Once both issues are fixed:

1. ✅ Webhook sends: `"Path": "/media/movies/Example.mkv"`
2. ✅ Watchdog logs: `Extracted file path: /media/movies/Example.mkv`
3. ✅ Container logs: `✓ File accessible`
4. ✅ Upscaling starts successfully
5. ✅ Output appears in `/mnt/media/upscaled/`

## Quick Reference

```bash
# Pull fixes
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

# Fix template
sudo ./scripts/fix_webhook_template_now.sh

# Diagnose volumes
./scripts/diagnose_path_issue.sh

# Fix volumes
sudo ./scripts/fix_docker_volumes.sh

# Test
tail -f /var/log/srgan-watchdog.log
# Play video
```

## Files Modified

- `docker-compose.yml` - Better default volume mounts
- `scripts/fix_webhook_template_now.sh` - NEW - Fix template
- `scripts/diagnose_path_issue.sh` - NEW - Diagnose volumes
- `scripts/fix_docker_volumes.sh` - NEW - Auto-fix volumes

---

**Run the fix scripts and both issues will be resolved!** 🚀
