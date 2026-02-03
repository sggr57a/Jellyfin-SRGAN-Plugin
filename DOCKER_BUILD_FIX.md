# Docker Build Context Fix

## ❌ Error

```
ERROR: unable to prepare context: path "srgan-upscaler" not found
```

## 🔍 Root Cause

This error occurs when:

1. **Running from wrong directory** - Must be in repository root (where `docker-compose.yml` is)
2. **Missing docker-compose.yml** - File not found in current directory
3. **Missing Dockerfile** - File not found in current directory

## ✅ Solution

The scripts now automatically verify the correct files exist before building.

---

## 🚀 How to Fix

### Option 1: Use Updated Scripts (Recommended)

The scripts now have built-in verification:

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Pull latest fixes
git pull origin main

# Run installer (with verification)
sudo ./scripts/install_all.sh

# Or rebuild existing installation
sudo ./scripts/rebuild_and_test.sh
```

The scripts will now:
- ✅ Check for `docker-compose.yml`
- ✅ Check for `Dockerfile`
- ✅ Show current directory on error
- ✅ Display helpful debug info

---

### Option 2: Manual Build

If running Docker commands manually:

```bash
# MUST be in repository root
cd /root/Jellyfin-SRGAN-Plugin

# Verify files exist
ls -la docker-compose.yml Dockerfile

# Then build
docker compose build srgan-upscaler
```

---

## 🐛 Common Mistakes

### ❌ Wrong: Running from scripts directory

```bash
cd /root/Jellyfin-SRGAN-Plugin/scripts
docker compose build srgan-upscaler
# ERROR: path "srgan-upscaler" not found
```

### ✅ Correct: Running from repository root

```bash
cd /root/Jellyfin-SRGAN-Plugin
docker compose build srgan-upscaler
# SUCCESS
```

---

## 🔍 Debugging

### Check Your Location

```bash
# Show current directory
pwd
# Should output: /root/Jellyfin-SRGAN-Plugin (or similar)

# List required files
ls -la docker-compose.yml Dockerfile
# Both should exist
```

### Verify Repository Structure

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Should see these files:
tree -L 1
.
├── docker-compose.yml     ← Required
├── Dockerfile             ← Required
├── requirements.txt
├── scripts/
├── models/
└── ...
```

---

## 📋 Updated Scripts

### install_all.sh

Now includes verification:

```bash
cd "${REPO_DIR}"

# Verify we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "✗ docker-compose.yml not found"
    exit 1
fi

if [[ ! -f "Dockerfile" ]]; then
    echo "✗ Dockerfile not found"
    exit 1
fi

# Then build
docker compose build srgan-upscaler
```

### rebuild_and_test.sh

Same verification added:

```bash
cd "${REPO_DIR}"

# Check for required files
if [[ ! -f "docker-compose.yml" ]] || [[ ! -f "Dockerfile" ]]; then
    echo "✗ Missing required files"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Then build
docker compose build --no-cache srgan-upscaler
```

---

## 🎯 Quick Fix Commands

```bash
# On your server:
cd /root/Jellyfin-SRGAN-Plugin

# Pull latest scripts with verification
git pull origin main

# Run with automatic verification
sudo ./scripts/rebuild_and_test.sh
```

---

## ✅ Verification

After pulling updates, the scripts will show:

```
Step 3: Rebuilding container...

Building from: /root/Jellyfin-SRGAN-Plugin

[Build proceeds successfully]
✓ Container rebuilt successfully
```

If there's still an error, you'll see helpful debug info:

```
✗ Missing docker-compose.yml or Dockerfile
Current directory: /root/some/wrong/path
docker-compose.yml exists: no
Dockerfile exists: no
```

---

## 📚 Related Issues

This error can also appear if:

1. **Wrong docker-compose.yml format**
   - Fix: Ensure `context: .` (not `context: srgan-upscaler`)

2. **Running old Docker Compose v1**
   - Fix: Use `docker compose` (v2), not `docker-compose` (v1)
   - Install: `apt install docker-compose-v2`

3. **Repository not cloned completely**
   - Fix: Re-clone repository

---

## 🎯 Summary

**Problem:** `path "srgan-upscaler" not found`  
**Cause:** Running build from wrong directory or missing files  
**Fix:** Updated scripts now verify location and show helpful errors  

**Deploy fix:**
```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
sudo ./scripts/rebuild_and_test.sh
```

No more confusing build errors! 🎉
