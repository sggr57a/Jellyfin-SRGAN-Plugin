# Troubleshooting Guide

Complete guide for diagnosing and fixing common issues with the SRGAN pipeline.

## Quick Diagnostics

Run these commands first to identify issues:

```bash
# 1. Verify system setup
python3 scripts/verify_setup.py

# 2. Check service status
./scripts/manage_watchdog.sh status

# 3. Test webhook
python3 scripts/test_webhook.py

# 4. Check service health
./scripts/manage_watchdog.sh health

# 5. View recent logs
./scripts/manage_watchdog.sh recent
```

## Common Issues

### 1. Systemd Service Issues

#### Service Won't Start

**Symptoms:**
- `systemctl status` shows "failed" or "inactive (dead)"
- Service immediately exits after starting

**Diagnosis:**
```bash
# Check status and error messages
./scripts/manage_watchdog.sh status

# View error logs
sudo journalctl -u srgan-watchdog.service -n 50
```

**Common Causes & Solutions:**

**A. Flask not installed**
```bash
# Install Flask for your user
pip3 install flask requests

# Verify installation
python3 -c "import flask; print('Flask OK')"

# Restart service
./scripts/manage_watchdog.sh restart
```

**B. Port 5000 already in use**
```bash
# Check what's using port 5000
lsof -i :5000

# Kill the conflicting process
sudo kill <PID>

# Or change the port (edit watchdog.py)
```

**C. Python not found**
```bash
# Check Python path
which python3

# If not found, install Python
sudo apt install python3 python3-pip
```

**D. Permissions error on cache directory**
```bash
# Create and fix permissions
mkdir -p ./cache
chmod 755 ./cache

# Restart service
./scripts/manage_watchdog.sh restart
```

#### Service Keeps Restarting

**Symptoms:**
- Service shows "activating (auto-restart)" repeatedly
- High restart count in systemctl status

**Diagnosis:**
```bash
# Monitor restart cycle
./scripts/manage_watchdog.sh logs
```

**Solutions:**

1. Check for import errors (missing dependencies)
2. Look for port conflicts
3. Check file permissions
4. Verify Docker is running: `systemctl status docker`

#### Service Running But Not Responding

**Symptoms:**
- Service shows "active (running)"
- Webhook health check fails

**Diagnosis:**
```bash
# Test endpoint
curl http://localhost:5000/health

# Check if process is actually listening
lsof -i :5000

# View logs
./scripts/manage_watchdog.sh logs
```

**Solutions:**

**A. Firewall blocking port 5000**
```bash
# Ubuntu/Debian
sudo ufw allow 5000
sudo ufw reload

# CentOS/RHEL
sudo firewall-cmd --add-port=5000/tcp --permanent
sudo firewall-cmd --reload
```

**B. Service bound to wrong interface**
- Check watchdog.py binds to `0.0.0.0:5000` (not `127.0.0.1`)

**C. Service crashed but systemd hasn't restarted it yet**
```bash
./scripts/manage_watchdog.sh restart
```

### 2. Webhook Not Triggering

#### No Webhook Received When Playing Video

**Symptoms:**
- No logs appear when playing video in Jellyfin
- Service is running but receives no requests

**Diagnosis:**
```bash
# Verify service is running
./scripts/manage_watchdog.sh status

# Check Jellyfin webhook plugin logs
# Dashboard → Plugins → Webhooks → View Logs

# Test webhook manually
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item": {"Path": "/test/path.mkv"}}'
```

**Common Causes & Solutions:**

**A. Webhook plugin not installed/enabled**
```bash
# In Jellyfin:
# 1. Dashboard → Plugins → Catalog
# 2. Install "Webhook" plugin
# 3. Restart Jellyfin
```

**B. Wrong webhook URL**
- Use server IP, not `localhost` if Jellyfin is on different machine
- Example: `http://192.168.1.100:5000/upscale-trigger`
- NOT: `http://localhost:5000/upscale-trigger` (unless same machine)

**C. Webhook not configured for correct event type**
- Ensure "Playback Start" is checked
- Ensure "Movie" and "Episode" are checked

**D. Network/firewall issue**
```bash
# Test from Jellyfin server
curl http://localhost:5000/health

# If fails, check firewall rules
```

#### "Item.Path" Not Found Error

**Symptoms:**
```
ERROR: No file path found in webhook payload!
Expected: data['Item']['Path']
```

**Diagnosis:**
- Check watchdog logs for the full payload received
- Verify webhook template configuration

**Solution:**

Ensure webhook template includes `{{Item.Path}}` with double curly braces:

```json
{
  "Item": {
    "Path": "{{Item.Path}}",
    "Name": "{{Item.Name}}",
    "Type": "{{Item.Type}}"
  }
}
```

**Common mistakes:**
- Using single curly braces: `{Item.Path}` ❌
- Wrong variable name: `{{ItemPath}}` ❌
- Missing quotes: `{Path: {{Item.Path}}}` ❌
- Wrong content type (not `application/json`)

### 3. File Path Issues

#### "Input file does not exist"

**Symptoms:**
```
ERROR: Input file does not exist: /path/to/file.mkv
Possible causes:
  1. Path mismatch between Jellyfin and watchdog host
```

**Diagnosis:**
```bash
# Check what path webhook sends (from logs)
# Then check if it exists on watchdog host
ls -lh /path/from/webhook
```

**Solutions:**

**Case A: Jellyfin and watchdog on same host**
- Paths should match exactly
- Verify Jellyfin library path: Dashboard → Libraries → Paths
- Check file exists: `ls -lh /path/to/file.mkv`
- Check permissions: File must be readable by watchdog user

**Case B: Jellyfin in Docker, watchdog on host**

Example: Jellyfin sees `/media/movies` but host path is `/mnt/media/movies`

**Solution 1: Fix Jellyfin volume mount**
```yaml
# In Jellyfin's docker-compose.yml
volumes:
  - /mnt/media:/media:ro  # Host path : Container path
```

**Solution 2: Add path translation to watchdog.py**
```python
# Edit scripts/watchdog.py around line 23
input_file = data.get("Item", {}).get("Path")

# Add path translation:
input_file = input_file.replace("/media/", "/mnt/media/")

# Restart service
./scripts/manage_watchdog.sh restart
```

**Case C: NFS mount not accessible**
```bash
# Check if mount is active
mount | grep /mnt/media

# Remount if needed
sudo mount -a

# Check permissions
ls -ld /mnt/media

# Check if watchdog user can access
sudo -u $USER ls /mnt/media
```

**Case D: Symbolic link issue**
```bash
# Check if path contains symlinks
ls -la /path/to/file

# Resolve to real path
readlink -f /path/to/file

# Use resolved path or fix symlink
```

### 4. Docker Container Issues

#### Container Won't Start

**Diagnosis:**
```bash
# Check container status
docker compose ps

# View logs
docker compose logs srgan-upscaler

# Try starting manually
docker compose up srgan-upscaler
```

**Common Causes & Solutions:**

**A. Docker not running**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

**B. GPU not accessible in container**
```bash
# Test GPU access
docker compose run --rm srgan-upscaler nvidia-smi

# If fails, check NVIDIA Container Toolkit
nvidia-container-cli info
```

**C. Volume mount errors**
```bash
# Check if paths exist
ls -ld /mnt/media
ls -ld ./cache

# Create if missing
mkdir -p ./cache ./models
```

**D. Image not built**
```bash
# Rebuild
docker compose build srgan-upscaler

# Check image exists
docker images | grep srgan
```

#### Container Runs But No Output File

**Symptoms:**
- Webhook triggers successfully
- Container starts and processes
- No upscaled file appears in output directory

**Diagnosis:**
```bash
# Check container logs
docker compose logs -f srgan-upscaler

# Check queue file
cat ./cache/queue.jsonl

# Check output directory
ls -lh /mnt/media/upscaled/
```

**Solutions:**

**A. Output directory doesn't exist**
```bash
# Create with correct permissions
sudo mkdir -p /mnt/media/upscaled
sudo chmod 755 /mnt/media/upscaled
```

**B. Output directory not writable**
```bash
# Check permissions
ls -ld /mnt/media/upscaled

# Fix permissions
sudo chown $USER:$USER /mnt/media/upscaled
```

**C. FFmpeg error**
- Check container logs for ffmpeg errors
- Common: codec not supported, invalid dimensions, corrupted input

**D. Volume mount mismatch**
- Check docker-compose.yml volume mappings
- Ensure `/data` in container maps to correct host path

#### GPU Errors in Container

**Symptoms:**
```
RuntimeError: CUDA error: out of memory
RuntimeError: No CUDA-capable device detected
```

**Solutions:**

**A. CUDA out of memory**
```bash
# Reduce resolution or batch size
# Edit docker-compose.yml:
# SRGAN_FFMPEG_BUFSIZE=50M  # Reduce from 100M

# Restart container
docker compose restart srgan-upscaler
```

**B. No CUDA device**
```bash
# Verify GPU works on host
nvidia-smi

# Test in container
docker compose run --rm srgan-upscaler nvidia-smi

# Check docker-compose.yml has GPU config:
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu, video]
```

### 5. Permission Issues

#### Permission Denied Errors

**Solutions:**

**A. Cache directory**
```bash
mkdir -p ./cache
chmod 755 ./cache
```

**B. Output directory**
```bash
sudo chown $USER:$USER /mnt/media/upscaled
sudo chmod 755 /mnt/media/upscaled
```

**C. Log files**
```bash
chmod 644 watchdog.log
```

**D. Scripts not executable**
```bash
chmod +x scripts/*.sh scripts/*.py
```

### 6. Network Issues

#### Webhook Unreachable from Jellyfin

**Symptoms:**
- Jellyfin shows connection error in webhook logs
- Timeout errors

**Diagnosis:**
```bash
# From Jellyfin server, test connectivity
curl http://<watchdog-host>:5000/health

# Check firewall
sudo iptables -L -n | grep 5000
```

**Solutions:**

**A. Firewall blocking port**
```bash
# Ubuntu
sudo ufw allow 5000

# CentOS
sudo firewall-cmd --add-port=5000/tcp --permanent
sudo firewall-cmd --reload
```

**B. SELinux blocking (CentOS/RHEL)**
```bash
# Check SELinux status
sestatus

# Allow port
sudo semanage port -a -t http_port_t -p tcp 5000

# Or set permissive mode (temporary)
sudo setenforce 0
```

**C. Docker network issue**
- Ensure watchdog runs on host, not in isolated Docker network
- Or configure Docker network properly

### 7. Model Issues

#### Model File Not Found

**Symptoms:**
```
NotImplementedError: SRGAN model not found at /app/models/swift_srgan_4x.pth
```

**Solution:**
```bash
# Download and setup model
./scripts/setup_model.sh

# Or manually
wget https://github.com/Koushik0901/Swift-SRGAN/releases/download/v0.1/swift_srgan_4x.pth.tar
mv swift_srgan_4x.pth.tar models/swift_srgan_4x.pth
```

#### Model Load Error

**Symptoms:**
```
RuntimeError: Error loading model state_dict
```

**Solutions:**

**A. Corrupted download**
```bash
# Re-download model
rm models/swift_srgan_4x.pth
./scripts/setup_model.sh
```

**B. Wrong model file**
- Ensure you're using Swift-SRGAN 4x model
- Check file size (should be ~400-500MB)

**C. CUDA version mismatch**
- Model was trained with different PyTorch/CUDA version
- Try setting `SRGAN_FP16=0` in docker-compose.yml

## Advanced Debugging

### Enable Verbose Logging

**Edit scripts/watchdog.py:**
```python
# Line 10, change from INFO to DEBUG
logging.basicConfig(
    level=logging.DEBUG,  # Was: logging.INFO
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
```

Restart service:
```bash
./scripts/manage_watchdog.sh restart
./scripts/manage_watchdog.sh logs
```

### Monitor Everything in Real-Time

```bash
# Terminal 1: Watchdog logs
./scripts/manage_watchdog.sh logs

# Terminal 2: Container logs
docker compose logs -f srgan-upscaler

# Terminal 3: Queue file
watch -n 1 cat ./cache/queue.jsonl

# Terminal 4: GPU usage
watch -n 1 nvidia-smi

# Terminal 5: Output directory
watch -n 1 ls -lh /mnt/media/upscaled/
```

### Test Complete Pipeline Manually

```bash
# 1. Add job to queue manually
echo '{"input":"/mnt/media/movies/test.mkv","output":"/mnt/media/upscaled/test.ts"}' \
  >> ./cache/queue.jsonl

# 2. Start container and watch
docker compose up srgan-upscaler

# 3. Check output
ls -lh /mnt/media/upscaled/test.ts
```

### Check System Resources

```bash
# Disk space
df -h /mnt/media

# Memory usage
free -h

# GPU memory
nvidia-smi

# CPU usage
top

# Network connections
netstat -tlnp | grep 5000
```

## Performance Issues

### Slow Upscaling

**Solutions:**

1. **Enable GPU hardware acceleration** (docker-compose.yml):
   ```yaml
   SRGAN_FFMPEG_HWACCEL=1
   SRGAN_FFMPEG_ENCODER=hevc_nvenc
   ```

2. **Use faster preset**:
   ```yaml
   SRGAN_FFMPEG_PRESET=p1  # Fastest
   ```

3. **Reduce buffer sizes** if memory limited:
   ```yaml
   SRGAN_FFMPEG_BUFSIZE=50M
   SRGAN_FFMPEG_RTBUFSIZE=50M
   ```

4. **Check GPU isn't throttling**:
   ```bash
   nvidia-smi -l 1  # Watch GPU usage
   ```

### High Memory Usage

**Solutions:**

1. Reduce FFmpeg buffer sizes
2. Process one file at a time (default behavior)
3. Set memory limits in docker-compose.yml:
   ```yaml
   deploy:
     resources:
       limits:
         memory: 8G
   ```

## Still Having Issues?

1. **Collect diagnostic information:**
   ```bash
   # Run verification
   python3 scripts/verify_setup.py > diagnostic.txt

   # Get service status
   ./scripts/manage_watchdog.sh status >> diagnostic.txt

   # Get recent logs
   ./scripts/manage_watchdog.sh recent >> diagnostic.txt

   # Get container logs
   docker compose logs srgan-upscaler >> diagnostic.txt
   ```

2. **Check documentation:**
   - [GETTING_STARTED.md](GETTING_STARTED.md) - Installation steps
   - [WEBHOOK_CONFIGURATION_CORRECT.md](WEBHOOK_CONFIGURATION_CORRECT.md) - Webhook configuration
   - [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md) - Service management

3. **Review configuration:**
   - docker-compose.yml settings
   - Jellyfin webhook template
   - File paths and permissions
   - Firewall rules

## Quick Reference: Log Locations

| Component | Log Location / Command |
|-----------|----------------------|
| **Watchdog Service** | `./scripts/manage_watchdog.sh logs` |
| **Systemd Journal** | `sudo journalctl -u srgan-watchdog.service -f` |
| **Container** | `docker compose logs -f srgan-upscaler` |
| **Manual Watchdog** | `./watchdog.log` (if started with -d flag) |
| **Jellyfin** | Dashboard → Logs |
| **Jellyfin Webhook** | Dashboard → Plugins → Webhooks → View Logs |
| **Queue File** | `cat ./cache/queue.jsonl` |

## Quick Reference: Test Commands

```bash
# Test watchdog health
curl http://localhost:5000/health

# Test webhook manually
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item": {"Path": "/path/to/test.mkv"}}'

# Test GPU in container
docker compose run --rm srgan-upscaler nvidia-smi

# Test ffmpeg in container
docker compose run --rm srgan-upscaler ffmpeg -version

# Test file access from container
docker compose run --rm srgan-upscaler ls -lh /data/movies/
```
