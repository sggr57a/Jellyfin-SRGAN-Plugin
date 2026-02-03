# install_all.sh - Complete Installation Guide

## What It Does

The `install_all.sh` script is a comprehensive, automated installer that handles **everything** needed to set up the SRGAN pipeline.

**No manual steps required** (except creating the Jellyfin API key when prompted and configuring the webhook).

---

## What Gets Installed

### 1. System Dependencies
- Docker Engine
- Docker Compose v2
- Python 3
- Flask and requests packages

### 2. Configuration
- Auto-detects media library paths
- Configures Docker volume mounts
- Creates environment configuration
- Saves Jellyfin API key securely

### 3. Services
- API-based watchdog (systemd service)
- Docker containers (srgan-upscaler, hls-server)
- Auto-start on boot

### 4. Cleanup
- Removes old template-based watchdog
- Deletes old webhook plugin files
- Cleans up deprecated scripts

### 5. Testing
- Tests API connectivity
- Verifies media access
- Validates service status

---

## Usage

```bash
# Clone repository
git clone <your-repo-url>
cd Jellyfin-SRGAN-Pipeline

# Run installer
sudo ./scripts/install_all.sh
```

**That's it!** The script handles everything else.

---

## What You Need to Provide

### During Installation

#### 1. Jellyfin API Key (when prompted)

```
Jellyfin Dashboard
  → Advanced
    → API Keys
      → Click "+"
        → Name: SRGAN Watchdog
          → Copy the generated key
```

Paste this key when the installer prompts for it.

#### 2. Webhook Configuration (when prompted)

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

---

## What Gets Cleaned Up

### Removed Automatically

1. **Old template-based watchdog service**
   - Stops `srgan-watchdog` service
   - Disables auto-start
   - Replaces with `srgan-watchdog-api`

2. **Old webhook plugin files**
   - `jellyfin-plugin-webhook/` directory (not needed for API approach)
   - Build scripts for webhook plugin

3. **Deprecated scripts**
   - Old `watchdog.py` → renamed to `watchdog.py.old`
   - Template-based configuration scripts

---

## Installation Steps (Automatic)

The script performs these steps automatically:

### Step 0: Check Prerequisites
- Detects OS
- Checks if running as root

### Step 1: Install System Dependencies
- Installs Docker (if missing)
- Verifies Docker Compose v2
- Installs Python 3
- Installs Flask and requests
- Checks for Jellyfin

### Step 2: Clean Up Old Files
- Stops old template-based watchdog
- Removes old webhook plugin files
- Deletes deprecated scripts

### Step 3: Configure Volume Mounts
- Auto-detects media library paths
- Updates `docker-compose.yml`
- Configures read-only mounts

### Step 4: Build Docker Container
- Builds `srgan-upscaler` image
- Validates build success

### Step 5: Get Jellyfin API Key
- Checks for existing API key
- Prompts for new key (if needed)
- Tests API connectivity
- Saves key securely

### Step 6: Install API-Based Watchdog
- Creates environment file
- Creates systemd service
- Starts and enables service

### Step 7: Start Docker Containers
- Starts all services
- Verifies container status

### Step 8: Create Directories
- Creates output directories
- Sets proper permissions
- Creates cache/queue file

### Step 9: Configure Webhook
- Displays configuration instructions
- Waits for user confirmation

### Step 10: Test Installation
- Tests watchdog API
- Tests session detection
- Tests container media access
- Shows final status

---

## After Installation

### Services Running

```bash
# Check service status
sudo systemctl status srgan-watchdog-api

# Check container status
docker ps
```

### View Logs

```bash
# Watchdog logs
sudo journalctl -u srgan-watchdog-api -f

# Container logs
docker logs srgan-upscaler -f
```

### Test It

1. Play a video in Jellyfin
2. Monitor logs (see above)
3. Check output: `ls -lh /mnt/media/upscaled/hls/`

---

## Configuration Files

### Created by Installer

| File | Purpose |
|------|---------|
| `/etc/default/srgan-watchdog-api` | Environment variables |
| `/etc/systemd/system/srgan-watchdog-api.service` | Systemd service |
| `${REPO}/.jellyfin_api_key` | Saved API key (secure) |
| `${REPO}/cache/queue.jsonl` | Job queue |
| `docker-compose.yml` | Updated with volume mounts |

### Modified by Installer

| File | Change |
|------|--------|
| `docker-compose.yml` | Updated volume mounts |
| `scripts/watchdog.py` | Renamed to `watchdog.py.old` |

---

## Troubleshooting

### Installation Failed

```bash
# Check what failed
cat /var/log/install_all.log

# Re-run specific step
sudo ./scripts/install_all.sh
```

### Service Won't Start

```bash
# Check service logs
sudo journalctl -u srgan-watchdog-api -n 50

# Common issues:
#   - API key invalid → Re-enter key
#   - Python packages missing → sudo pip3 install flask requests
#   - Port 5432 in use → Check: sudo lsof -i :5432
```

### Container Can't Find Media

```bash
# Run diagnostic
./scripts/diagnose_path_issue.sh

# Manual fix
./scripts/fix_docker_volumes.sh
```

### API Key Issues

```bash
# Test API manually
curl -H "X-Emby-Token: YOUR_KEY" http://localhost:8096/Sessions

# Re-enter API key
rm ${REPO}/.jellyfin_api_key
sudo ./scripts/install_all.sh  # Will prompt again
```

---

## What If I Need to Re-Install?

### Complete Re-Install

```bash
# 1. Stop services
sudo systemctl stop srgan-watchdog-api
docker compose down

# 2. Clean up (optional)
sudo rm -f /etc/default/srgan-watchdog-api
sudo rm -f /etc/systemd/system/srgan-watchdog-api.service
rm -f ${REPO}/.jellyfin_api_key

# 3. Re-run installer
sudo ./scripts/install_all.sh
```

### Keep Configuration

```bash
# Just re-run installer
# It will detect existing API key and configuration
sudo ./scripts/install_all.sh
```

---

## Advanced Options

### Custom Media Paths

If auto-detection doesn't find your media:

```bash
# Installer will prompt:
# "Enter path to your media library: "

# Type your custom path
/your/custom/path
```

### Custom Jellyfin URL

```bash
# Edit before running installer
export JELLYFIN_URL=http://your-server:8096

# Then run
sudo ./scripts/install_all.sh
```

### Skip Jellyfin Check

```bash
# If Jellyfin is on another server
# Installer will ask: "Continue without Jellyfin?"
# Answer: y
```

---

## Summary

**One command installs everything:**

```bash
sudo ./scripts/install_all.sh
```

**Manual steps (during install):**
1. Provide Jellyfin API key
2. Configure webhook

**After install:**
1. Play video
2. Watch it upscale!

**No manual file editing, copying, or configuration needed!** 🚀
