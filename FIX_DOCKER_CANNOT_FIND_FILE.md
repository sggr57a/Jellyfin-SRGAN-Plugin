# Fix: Docker Container Cannot Find Input File

## Problem

Webhook sends path but container can't find the file:
```
Extracted file path: /media/movies/Example.mkv
ERROR: Input file not found in container
```

## Root Cause

**Volume Mount Mismatch**

The Docker container needs the same path that Jellyfin uses:
- **Jellyfin sees:** `/media/movies/Example.mkv`
- **Container sees:** ???

If `/media` isn't mounted in the container, the file can't be found.

## Quick Fix - Run on Your Server

### Step 1: Diagnose the Issue

```bash
ssh root@192.168.101.164
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

# See what paths are being used and what's accessible
./scripts/diagnose_path_issue.sh
```

**This shows:**
- What path the webhook is sending
- What volume mounts are configured
- What paths the container can access
- Specific fix commands for your setup

### Step 2: Auto-Fix Volume Mounts

```bash
sudo ./scripts/fix_docker_volumes.sh
```

**This does:**
- Auto-detects your media directories
- Updates docker-compose.yml with correct mounts
- Recreates container with new mounts
- Tests that files are now accessible

### Step 3: Or Manual Fix

If auto-fix doesn't work, edit manually:

```bash
nano /root/Jellyfin-SRGAN-Plugin/docker-compose.yml
```

Find the `srgan-upscaler` service and update volumes:

```yaml
  srgan-upscaler:
    volumes:
      # ADD YOUR JELLYFIN MEDIA PATHS HERE
      - /media:/media:ro              # If Jellyfin uses /media/movies
      - /mnt/media:/mnt/media:ro      # If Jellyfin uses /mnt/media/movies
      - /srv/media:/srv/media:ro      # If Jellyfin uses /srv/media
      
      # Keep these
      - /mnt/media/upscaled:/data/upscaled
      - ./cache:/app/cache
      - ./models:/app/models:ro
```

Then recreate container:
```bash
cd /root/Jellyfin-SRGAN-Plugin
docker compose down srgan-upscaler
docker compose up -d srgan-upscaler
```

## How to Find Your Jellyfin Media Path

### Method 1: Check Jellyfin Dashboard
1. Open Jellyfin Dashboard
2. Libraries → (select a library) → Manage Library
3. Look at "Folders" - this shows the actual paths
4. Example: `/media/movies`, `/mnt/media/tv`, etc.

### Method 2: Check Jellyfin Configuration
```bash
# Find library paths in Jellyfin config
grep -r "<Path>" /var/lib/jellyfin/data/*.xml 2>/dev/null | grep -v "<CollectionType>"

# Example output:
# <Path>/media/movies</Path>
# <Path>/media/tv</Path>
```

### Method 3: Check Watchdog Logs
```bash
# Play a video in Jellyfin, then check what path was sent
grep "Extracted file path:" /var/log/srgan-watchdog.log | tail -1

# Example: Extracted file path: /media/movies/Example.mkv
# This means you need: - /media:/media:ro
```

## Example Configurations

### If Jellyfin uses `/media`
```yaml
volumes:
  - /media:/media:ro
  - /mnt/media/upscaled:/data/upscaled
  - ./cache:/app/cache
  - ./models:/app/models:ro
```

### If Jellyfin uses `/mnt/media`
```yaml
volumes:
  - /mnt/media:/mnt/media:ro
  - /mnt/media/upscaled:/data/upscaled
  - ./cache:/app/cache
  - ./models:/app/models:ro
```

### If Jellyfin uses multiple paths
```yaml
volumes:
  - /media/movies:/media/movies:ro
  - /media/tv:/media/tv:ro
  - /mnt/storage/movies:/mnt/storage/movies:ro
  - /mnt/media/upscaled:/data/upscaled
  - ./cache:/app/cache
  - ./models:/app/models:ro
```

## Key Points

### ✅ Path Must Match EXACTLY
- If Jellyfin path is `/media/movies/file.mkv`
- Container mount must be: `/media:/media:ro`
- NOT: `/media:/data:ro` (different path in container)

### ✅ Use :ro (Read-Only) for Media
- Media files only need read access
- `:ro` prevents accidental modification
- Output directory needs `:rw` (read-write)

### ✅ Multiple Mounts Are OK
- You can mount multiple directories
- Mount each of Jellyfin's library folders
- Container will have access to all of them

## Testing After Fix

### Test 1: Check Container Can See Files
```bash
# Get a file path from Jellyfin
JELLYFIN_PATH="/media/movies/Example.mkv"  # Replace with actual path

# Test if container can see it
docker compose -f /root/Jellyfin-SRGAN-Plugin/docker-compose.yml exec srgan-upscaler test -f "${JELLYFIN_PATH}" && echo "✓ FILE FOUND" || echo "✗ FILE NOT FOUND"
```

### Test 2: List Files in Container
```bash
# See what the container can access
docker compose -f /root/Jellyfin-SRGAN-Plugin/docker-compose.yml exec srgan-upscaler ls -la /media/movies/ | head -10
```

### Test 3: Full End-to-End Test
```bash
# Terminal 1: Monitor logs
tail -f /var/log/srgan-watchdog.log

# Terminal 2: Play video in Jellyfin

# Should see:
# Extracted file path: /media/movies/Example.mkv
# ✓ File accessible in container
# Starting upscaling...
```

## Updated docker-compose.yml

The new default now includes common paths:
```yaml
volumes:
  - /media:/media:ro                    # NEW
  - /mnt/media:/mnt/media:ro            # UPDATED
  - /srv/media:/srv/media:ro            # NEW
  - /mnt/media/upscaled:/data/upscaled  # Kept
  - ./cache:/app/cache                   # Kept
  - ./models:/app/models:ro              # Kept
```

## After Fixing Volumes

1. ✅ Pull latest code: `git pull origin main`
2. ✅ Recreate container: `docker compose up -d --force-recreate srgan-upscaler`
3. ✅ Test file access: Run diagnose script
4. ✅ Play video in Jellyfin
5. ✅ Check upscaling starts

## Troubleshooting

### Container still can't find files

**Check exact path:**
```bash
# What path is Jellyfin sending?
grep "Extracted file path:" /var/log/srgan-watchdog.log | tail -1

# Is it mounted in container?
docker compose exec srgan-upscaler mount | grep media
```

### Permission denied in container

**Check file permissions on host:**
```bash
ls -lh /media/movies/Example.mkv

# Container runs as root, so should be readable
```

### Symlinks not working

**Use rslave mount option:**
```yaml
- /media:/media:rslave  # Instead of :ro
```

## Complete Fix Commands

```bash
# On server: 192.168.101.164
ssh root@192.168.101.164
cd /root/Jellyfin-SRGAN-Plugin

# Pull latest docker-compose.yml with better defaults
git pull origin main

# Diagnose issue
./scripts/diagnose_path_issue.sh

# Auto-fix (recommended)
sudo ./scripts/fix_docker_volumes.sh

# Or manually edit docker-compose.yml and:
docker compose down srgan-upscaler
docker compose up -d srgan-upscaler

# Test
docker compose exec srgan-upscaler ls -la /media/
# Should show your media files
```

## Success Indicators

✅ `diagnose_path_issue.sh` shows file accessible in container  
✅ `docker compose exec srgan-upscaler test -f /media/movies/file.mkv` returns success  
✅ Watchdog logs show "Starting upscaling..." (not "file not found")  
✅ Upscaled files appear in `/mnt/media/upscaled/`  

**Fix the volume mounts and the container will find your files!** 🚀
