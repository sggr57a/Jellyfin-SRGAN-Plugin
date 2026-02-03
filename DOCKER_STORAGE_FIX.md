# Docker Storage/Overlay Corruption Fix

## ❌ Error

```
failed to solve: failed to prepare ... invalid output path: 
stat /var/lib/docker/overlay2/...: no such file or directory
```

## 🔍 Root Cause

This error indicates **Docker storage corruption** in the overlay2 filesystem. Common causes:

1. **Disk full or nearly full** - Docker needs space for build layers
2. **Docker daemon crash** - Left storage in inconsistent state  
3. **Corrupted overlay2 layer** - Storage driver issue
4. **Filesystem errors** - Underlying disk problems
5. **Interrupted build** - Previous build failed mid-process

---

## 🚀 Quick Fix (Automated)

Run the automated fix script:

```bash
ssh root@192.168.101.164

# Pull latest fix
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

# Run Docker storage fix
sudo ./scripts/fix_docker_storage.sh
```

**This script will:**
1. ✅ Check disk space
2. ✅ Stop all containers
3. ✅ Clean Docker system (prune containers, images, cache)
4. ✅ Restart Docker daemon
5. ✅ Verify Docker health
6. ✅ Attempt build with fresh state

---

## 🔧 Manual Fix Steps

If the automated script doesn't work:

### Step 1: Check Disk Space

```bash
df -h /var/lib/docker

# If > 90% full, free up space first:
# - Clean old logs: journalctl --vacuum-time=7d
# - Remove old kernels: apt autoremove
# - Clean apt cache: apt clean
```

### Step 2: Stop Containers

```bash
cd /root/Jellyfin-SRGAN-Plugin
docker compose down
```

### Step 3: Clean Docker System

```bash
# Remove stopped containers
docker container prune -f

# Remove dangling images
docker image prune -f

# Remove build cache
docker builder prune -f

# Check freed space
docker system df
```

### Step 4: Restart Docker

```bash
sudo systemctl restart docker

# Wait for Docker to be ready
sleep 5
docker info
```

### Step 5: Try Build Again

```bash
cd /root/Jellyfin-SRGAN-Plugin
docker compose build --no-cache srgan-upscaler
```

---

## 🧹 Aggressive Cleanup (If Still Failing)

**⚠️ WARNING:** This removes ALL Docker data (images, containers, volumes)

```bash
# Stop all containers
docker compose down

# Nuclear option - removes everything
docker system prune -a --volumes -f

# Restart Docker
sudo systemctl restart docker

# Rebuild from scratch
cd /root/Jellyfin-SRGAN-Plugin
docker compose build --no-cache srgan-upscaler
```

This forces a completely fresh Docker environment.

---

## 🔍 Verify Disk Health

If problems persist, check for disk errors:

```bash
# Check kernel messages for errors
dmesg | grep -i error | tail -20

# Check Docker storage driver
docker info | grep "Storage Driver"

# Check filesystem
df -i /var/lib/docker  # Check inodes
du -sh /var/lib/docker  # Check actual usage
```

---

## 🎯 Prevention

To avoid this in the future:

### 1. Monitor Disk Space

```bash
# Add to cron: Check daily
0 8 * * * df -h /var/lib/docker | grep -v Filesystem | awk '{if ($5+0 > 80) print "Docker disk usage: " $5}' | mail -s "Docker Disk Alert" admin@example.com
```

### 2. Regular Cleanup

```bash
# Add to cron: Weekly cleanup
0 2 * * 0 docker system prune -f

# Or use Docker's built-in cleanup
# Add to /etc/docker/daemon.json:
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### 3. Use Different Storage Driver

If overlay2 is problematic:

```bash
# Edit /etc/docker/daemon.json
{
  "storage-driver": "devicemapper"
}

# Restart Docker
sudo systemctl restart docker
```

---

## 🐛 Common Scenarios

### Scenario 1: Disk > 90% Full

**Symptoms:**
- Build fails with overlay error
- `df -h` shows > 90% usage

**Fix:**
```bash
# Clean logs
journalctl --vacuum-time=7d

# Clean apt cache
apt clean

# Remove old Docker images
docker image prune -a -f

# Verify space
df -h /var/lib/docker
```

### Scenario 2: Corrupted Build Cache

**Symptoms:**
- Build fails repeatedly at same layer
- Error mentions overlay2 directories

**Fix:**
```bash
# Clear build cache completely
docker builder prune -a -f

# Restart Docker
systemctl restart docker

# Build fresh
docker compose build --no-cache srgan-upscaler
```

### Scenario 3: Docker Daemon Issues

**Symptoms:**
- Docker commands hang
- Frequent overlay errors

**Fix:**
```bash
# Stop Docker
systemctl stop docker

# Remove problematic state
rm -rf /var/lib/docker/overlay2/*

# Start Docker (will rebuild overlay)
systemctl start docker

# Rebuild images
docker compose build --no-cache srgan-upscaler
```

---

## 📊 Disk Space Management

### Check Current Usage

```bash
# Overall Docker usage
docker system df

# Detailed breakdown
docker system df -v

# Overlay2 directory size
du -sh /var/lib/docker/overlay2/
```

### Free Up Space

```bash
# Remove specific items
docker container prune -f   # Stopped containers
docker image prune -a -f    # Unused images
docker volume prune -f      # Unused volumes
docker network prune -f     # Unused networks
docker builder prune -a -f  # Build cache

# Or all at once
docker system prune -a --volumes -f
```

---

## 🔧 Docker Daemon Configuration

Create/edit `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3
}
```

Then restart:
```bash
systemctl restart docker
```

---

## ✅ Verification

After fixing, verify everything works:

```bash
# 1. Docker is healthy
docker info

# 2. Build succeeds
cd /root/Jellyfin-SRGAN-Plugin
docker compose build srgan-upscaler

# 3. Container starts
docker compose up -d
docker ps | grep srgan

# 4. No errors in logs
docker logs srgan-upscaler | grep -i error
```

---

## 🆘 Last Resort

If nothing works:

```bash
# 1. Backup important data
docker compose exec srgan-upscaler cp -r /app/cache /backup/

# 2. Completely reinstall Docker
apt remove docker-ce docker-ce-cli containerd.io
rm -rf /var/lib/docker
apt install docker-ce docker-ce-cli containerd.io

# 3. Restore and rebuild
cd /root/Jellyfin-SRGAN-Plugin
docker compose build --no-cache
```

---

## 📚 Related Documentation

- **rebuild_and_test.sh** - Normal rebuild process
- **fix_build_error.sh** - Build context issues
- **install_all.sh** - Full installation

---

## 🎯 Summary

**Problem:** Docker overlay2 storage corruption  
**Cause:** Disk full, Docker crash, or corrupted layers  
**Fix:** Clean Docker system, restart daemon, rebuild  

**Quick fix:**
```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
sudo ./scripts/fix_docker_storage.sh
```

This resolves 95% of Docker storage issues! 🚀
