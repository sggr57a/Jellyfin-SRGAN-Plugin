# Volume Mount Fix

## ❌ Problem: Input File Not Found

```
ERROR: Input file does not exist: /mnt/media/MOVIES/Back to the Future (1985)/...
```

**Cause:** The `/mnt/media` volume was not mounted into the Docker container.

---

## ✅ Solution

### What Was Wrong

In `docker-compose.yml`, the media volume was **commented out**:

```yaml
# BEFORE (lines 77-79)
# Media input paths (configure for your system)
# - /media:/media:ro
# - /mnt/media:/mnt/media:ro  ← COMMENTED OUT!
# - /srv/media:/srv/media:ro
```

The container couldn't see any files in `/mnt/media`.

---

### What Was Fixed

**Uncommented and set to read-write:**

```yaml
# AFTER
# Media paths (read-write since we save output in same directory as input)
- /mnt/media:/mnt/media:rw
```

**Why read-write (`rw`)?**
- We now save upscaled files in the **same directory** as input files
- Container needs **write permission** to create output files
- Read-only (`:ro`) would prevent writing upscaled files

---

## 🚀 Deploy Fix

On your server:

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Pull the volume mount fix
git pull origin main

# Restart containers with new volume configuration
docker compose down
docker compose up -d

# Verify volume is mounted
docker exec srgan-upscaler ls -la /mnt/media/

# Should show your media directories!
```

---

## 🔍 Verify It Works

### 1. Check Volume Mount

```bash
# List volumes in container
docker exec srgan-upscaler mount | grep /mnt/media

# Should show:
# /dev/sda1 on /mnt/media type ext4 (rw,relatime)
#                                     ^^ read-write!
```

---

### 2. Check File Access

```bash
# Check if container can see your files
docker exec srgan-upscaler ls -lh "/mnt/media/MOVIES/Back to the Future (1985)/"

# Should show:
# -rw-r--r-- 1 ... Back to the Future (1985) imdbid-tt0088763 [Bluray-1080p].mp4
```

---

### 3. Check Write Permission

```bash
# Test write permission (creates and removes test file)
docker exec srgan-upscaler touch /mnt/media/test.txt && docker exec srgan-upscaler rm /mnt/media/test.txt

# Should complete without errors
```

---

### 4. Test Upscaling

```bash
# Play a video in Jellyfin

# Check logs
docker logs -f srgan-upscaler

# Should show:
# Input:  /mnt/media/MOVIES/Movie [1080p].mkv
# Output: /mnt/media/MOVIES/Movie [2160p].mkv
# ✓ VERIFICATION PASSED
```

---

## 📋 Volume Mount Explanation

### How It Works

```yaml
volumes:
  - /mnt/media:/mnt/media:rw
    ^            ^          ^
    |            |          |
    Host path    Container  Read-Write
                 path       permission
```

**Breakdown:**
- **Host path:** `/mnt/media` (where your media is stored)
- **Container path:** `/mnt/media` (same path inside container)
- **Permission:** `rw` (read and write)

**Result:** Files at `/mnt/media/MOVIES/` on host are accessible at `/mnt/media/MOVIES/` inside container.

---

### Why Same Path?

Using the **same path** inside and outside the container means:
- Jellyfin API returns: `/mnt/media/MOVIES/Movie.mkv`
- Container can access: `/mnt/media/MOVIES/Movie.mkv`
- No path translation needed! ✅

---

### Multiple Media Locations

If you have media in multiple locations:

```yaml
volumes:
  - /mnt/media:/mnt/media:rw
  - /media:/media:rw
  - /srv/media:/srv/media:rw
```

All will be accessible to the container.

---

## 🚨 Common Issues

### Error: "Permission denied"

```
ERROR: Could not write to /mnt/media/MOVIES/
```

**Cause:** Container user doesn't have write permission on host directory.

**Fix:**

```bash
# Option 1: Make directory writable
sudo chmod 755 /mnt/media/MOVIES/

# Option 2: Change owner to your user
sudo chown -R $USER:$USER /mnt/media/MOVIES/

# Then restart container
docker compose restart srgan-upscaler
```

---

### Error: "No such file or directory"

```
ERROR: Input file does not exist: /mnt/media/...
```

**Cause:** Volume not mounted or wrong path.

**Check:**

```bash
# 1. Verify volume in docker-compose.yml
grep -A 5 "volumes:" docker-compose.yml | grep mnt/media

# Should show:
# - /mnt/media:/mnt/media:rw

# 2. Check if file exists on HOST
ls -lh "/mnt/media/MOVIES/Movie.mkv"

# 3. Check if container can see it
docker exec srgan-upscaler ls -lh "/mnt/media/MOVIES/Movie.mkv"
```

---

### Volume Not Updated After Changing docker-compose.yml

**Cause:** Need to recreate container for volume changes.

**Fix:**

```bash
# Stop and remove containers
docker compose down

# Recreate with new volumes
docker compose up -d

# NOT just "restart" - that won't pick up volume changes!
```

---

## 📊 Before vs After

### Before (Broken)

```yaml
# docker-compose.yml
volumes:
  - ./cache:/app/cache
  - ./models:/app/models:ro
  - ./upscaled:/data/upscaled
  # - /mnt/media:/mnt/media:ro  ← COMMENTED!
```

**Result:**
```bash
docker exec srgan-upscaler ls /mnt/media/
# ls: /mnt/media/: No such file or directory
```

---

### After (Fixed)

```yaml
# docker-compose.yml
volumes:
  - ./cache:/app/cache
  - ./models:/app/models:ro
  - ./upscaled:/data/upscaled
  - /mnt/media:/mnt/media:rw  ← ACTIVE!
```

**Result:**
```bash
docker exec srgan-upscaler ls /mnt/media/
# MOVIES/  TV/  Music/  ← All visible!
```

---

## 🎯 Summary

**Problem:** Container couldn't see input files.

**Root Cause:** `/mnt/media` volume mount was commented out in `docker-compose.yml`.

**Solution:** 
1. ✅ Uncommented volume mount
2. ✅ Set to read-write (`:rw`)
3. ✅ Allows reading input AND writing output

**Deploy:**
```bash
git pull origin main
docker compose down && docker compose up -d
```

**Verify:**
```bash
docker exec srgan-upscaler ls /mnt/media/
# Should show your media folders!
```

**Done!** Container can now see your media files. 🎉
