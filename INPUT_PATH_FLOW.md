# Input Path Flow - How File Locations Are Determined

## Overview

The input file path flows through multiple components from Jellyfin to the Docker container. Understanding this flow is crucial for troubleshooting path-related issues.

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     INPUT PATH FLOW                              │
└─────────────────────────────────────────────────────────────────┘

1. Jellyfin (Server)
   │
   ├─ Media Library Path: /mnt/media/movies/film.mkv
   │  (This is where Jellyfin stores/accesses media files)
   │
   └─ Webhook sends to watchdog:
      POST http://localhost:5000/upscale-trigger
      {
        "Item": {
          "Path": "/mnt/media/movies/film.mkv"  ← Jellyfin's path
        }
      }

2. Watchdog (Python on Host)
   │
   ├─ Receives: data.get("Item", {}).get("Path")
   │  → input_file = "/mnt/media/movies/film.mkv"
   │
   ├─ Validates: os.path.exists(input_file)
   │  ✓ File must exist on the watchdog host at this path
   │
   └─ Adds to queue:
      {
        "input": "/mnt/media/movies/film.mkv",   ← Same path
        "output": "/mnt/media/upscaled/film.ts",
        "streaming": true
      }

3. Docker Container (srgan-upscaler)
   │
   ├─ Volume Mount: /mnt/media:/data:rslave
   │  (Maps host /mnt/media to container /data)
   │
   ├─ Queue job has: input="/mnt/media/movies/film.mkv"
   │
   ├─ Container resolves to: /data/movies/film.mkv
   │  (/mnt/media on host = /data in container)
   │
   └─ FFmpeg processes: /data/movies/film.mkv
      → Outputs to: /data/upscaled/film.ts
```

## Step-by-Step Breakdown

### 1. Jellyfin Sends Webhook

**Location:** Jellyfin server
**Action:** User plays video in Jellyfin
**Path used:** Jellyfin's media library path

```json
POST http://localhost:5000/upscale-trigger
Content-Type: application/json

{
  "Event": "PlaybackStart",
  "Item": {
    "Path": "/mnt/media/movies/example.mkv",
    "Name": "Example Movie"
  },
  "User": { ... }
}
```

**Key Point:** The `Item.Path` field contains the **full absolute path** as Jellyfin sees it.

---

### 2. Watchdog Receives and Validates

**File:** `scripts/watchdog.py`
**Lines:** 38-62

```python
# Extract file path from webhook payload
input_file = data.get("Item", {}).get("Path")
# → input_file = "/mnt/media/movies/example.mkv"

# Validate file exists on watchdog host
if not os.path.exists(input_file):
    return error("File not found")
```

**Key Validation:**
```python
os.path.exists(input_file)  # Must return True
```

This means the watchdog host must have access to the file at **exactly the same path** that Jellyfin reports.

**Example:**
- Jellyfin path: `/mnt/media/movies/film.mkv`
- Watchdog host: Must also see `/mnt/media/movies/film.mkv`

---

### 3. Queue Job Created

**File:** `scripts/watchdog.py`
**Lines:** 137-142

```python
payload = json.dumps({
    "input": input_file,           # "/mnt/media/movies/example.mkv"
    "output": output_file,          # "/data/upscaled/example.ts"
    "hls_dir": hls_dir,            # "/data/upscaled/hls/example"
    "streaming": True
})

# Written to: ./cache/queue.jsonl
```

**Important:** The input path is written to the queue **exactly as received** from Jellyfin.

---

### 4. Docker Container Processes

**File:** `docker-compose.yml`
**Lines:** 37-39

```yaml
volumes:
  - /mnt/media:/data:rslave
  - ./cache:/app/cache
```

**Volume Mount:** `/mnt/media` (host) → `/data` (container)

**Path Translation:**
```
Host path:      /mnt/media/movies/film.mkv
Container path: /data/movies/film.mkv
                ^^^^
                Maps /mnt/media → /data
```

---

### 5. Pipeline Reads Queue

**File:** `scripts/srgan_pipeline.py`
**Lines:** 185-200

```python
def _dequeue_job(queue_file):
    # Read job from queue
    job = json.loads(line)

    # Extract paths
    input_path = job["input"]      # "/mnt/media/movies/film.mkv"
    output_path = job["output"]    # "/data/upscaled/film.ts"

    return input_path, output_path
```

**But wait!** The container receives `/mnt/media/movies/film.mkv` but needs to access it as `/data/movies/film.mkv`.

**How is this resolved?**

The volume mount automatically handles this:
- Container tries to open: `/mnt/media/movies/film.mkv`
- Docker sees `/mnt/media` is mounted from host
- Docker translates to: `/data/movies/film.mkv` in container filesystem
- File is accessible!

---

### 6. FFmpeg Processing

**File:** `scripts/srgan_pipeline.py`
**Lines:** 15-58

```python
def _run_ffmpeg(input_path, output_path, width, height):
    cmd = [
        "ffmpeg",
        "-i", input_path,          # "/mnt/media/movies/film.mkv"
        "-vf", f"scale={width}:{height}",
        "-c:v", encoder,
        output_path                # "/data/upscaled/film.ts"
    ]
    subprocess.check_call(cmd)
```

**Inside Container:**
- Reads from: `/mnt/media/movies/film.mkv` (via volume mount)
- Writes to: `/data/upscaled/film.ts`

**On Host:**
- Actually reads: `/mnt/media/movies/film.mkv`
- Actually writes: `/mnt/media/upscaled/film.ts`

---

## Configuration Points

### 1. Jellyfin Media Library

**Location:** Jellyfin Dashboard → Libraries

```
Name: Movies
Path: /mnt/media/movies
```

This defines what paths Jellyfin will report in webhooks.

---

### 2. Watchdog Environment

**File:** `scripts/watchdog.py`
**Default:** No path translation

The watchdog expects to access files at the **same paths** Jellyfin uses.

**Environment Variables:**
```bash
# Output directory (where upscaled files go)
export UPSCALED_DIR=/data/upscaled

# Queue file location
export SRGAN_QUEUE_FILE=./cache/queue.jsonl
```

---

### 3. Docker Volume Mounts

**File:** `docker-compose.yml`

```yaml
volumes:
  - /mnt/media:/data:rslave
  #    ↑          ↑
  #  Host path  Container path
```

**Key Configuration:**
- **Host path:** Where files actually exist on your system
- **Container path:** Where the container sees them
- **Mount mode:** `rslave` = propagate mounts

**Example Configurations:**

**NFS Mount:**
```yaml
volumes:
  - /mnt/nfs-media:/data:rslave
```

**Local Storage:**
```yaml
volumes:
  - /home/user/Videos:/data:rslave
```

**Multiple Mounts:**
```yaml
volumes:
  - /mnt/media:/data:rslave
  - /mnt/media2:/data2:rslave
```

---

### 4. Output Directory

**Environment Variable:** `UPSCALED_DIR`

**In watchdog.py:**
```python
upscaled_dir = os.environ.get("UPSCALED_DIR", "/data/upscaled")
output_file = os.path.join(upscaled_dir, f"{base_name}.ts")
```

**In docker-compose.yml:**
```yaml
environment:
  - UPSCALED_DIR=/data/upscaled
```

With volume mount `/mnt/media:/data`:
- Container writes to: `/data/upscaled/film.ts`
- Host sees it at: `/mnt/media/upscaled/film.ts`

---

## Common Path Configurations

### Configuration 1: Single Media Mount

**Scenario:** All media on one mount point

```yaml
# docker-compose.yml
volumes:
  - /mnt/media:/data:rslave

environment:
  - UPSCALED_DIR=/data/upscaled
```

**Jellyfin Library:** `/mnt/media/movies`

**Flow:**
1. Jellyfin reports: `/mnt/media/movies/film.mkv`
2. Watchdog validates: `/mnt/media/movies/film.mkv` ✓
3. Container reads: `/mnt/media/movies/film.mkv` (via `/data` mount)
4. Container writes: `/data/upscaled/film.ts`
5. Host has: `/mnt/media/upscaled/film.ts` ✓

---

### Configuration 2: Separate Input/Output

**Scenario:** Input from NFS, output to local SSD

```yaml
# docker-compose.yml
volumes:
  - /mnt/nfs:/data/input:ro        # Read-only input
  - /mnt/ssd:/data/output:rw       # Writable output

environment:
  - UPSCALED_DIR=/data/output/upscaled
```

**Jellyfin Library:** `/mnt/nfs/movies`

**Flow:**
1. Jellyfin reports: `/mnt/nfs/movies/film.mkv`
2. Watchdog validates: `/mnt/nfs/movies/film.mkv` ✓
3. Container reads: `/mnt/nfs/movies/film.mkv` (via `/data/input`)
4. Container writes: `/data/output/upscaled/film.ts`
5. Host has: `/mnt/ssd/upscaled/film.ts` ✓

---

### Configuration 3: Docker Network Jellyfin

**Scenario:** Jellyfin also running in Docker

```yaml
# docker-compose.yml
services:
  jellyfin:
    volumes:
      - /mnt/media:/media:ro
    # Jellyfin sees: /media/movies/film.mkv

  srgan-upscaler:
    volumes:
      - /mnt/media:/data:rslave
    # Container sees: /data/movies/film.mkv
```

**Problem:** Jellyfin reports `/media/movies/film.mkv` but watchdog expects `/mnt/media/movies/film.mkv`

**Solution:** Mount Jellyfin at the same path:

```yaml
services:
  jellyfin:
    volumes:
      - /mnt/media:/mnt/media:ro  # Same path as host
```

---

## Path Validation Checklist

### ✅ Verify Path Flow

Run these commands to verify each step:

**1. Check Jellyfin's path:**
```bash
# View webhook payload in Jellyfin logs
sudo tail -f /var/log/jellyfin/jellyfin.log | grep webhook
```

**2. Check watchdog sees it:**
```bash
# Test webhook manually
curl -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item":{"Path":"/mnt/media/movies/test.mkv"}}'

# Check watchdog logs
sudo journalctl -u srgan-watchdog -f
```

**3. Check file exists on host:**
```bash
# Watchdog host must have access
ls -lh /mnt/media/movies/test.mkv
```

**4. Check Docker mount:**
```bash
# Enter container
docker exec -it srgan-upscaler bash

# Verify mount point
ls -lh /data/movies/test.mkv

# Or test directly
docker exec srgan-upscaler ls -lh /mnt/media/movies/test.mkv
```

**5. Check output directory:**
```bash
# On host
ls -lh /mnt/media/upscaled/

# In container
docker exec srgan-upscaler ls -lh /data/upscaled/
```

---

## Troubleshooting Path Issues

### Issue: "File not found" Error

**Error in watchdog:**
```
ERROR: Input file does not exist: /mnt/media/movies/film.mkv
```

**Causes:**
1. **Path mismatch:** Jellyfin and watchdog see different paths
2. **Mount not accessible:** NFS/SMB mount not connected
3. **Permissions:** Watchdog user can't read the file

**Fix:**
```bash
# 1. Check file exists
ls -lh /mnt/media/movies/film.mkv

# 2. Check mount point
mount | grep /mnt/media

# 3. Check permissions
sudo -u srgan-watchdog ls /mnt/media/movies/film.mkv

# 4. Check Jellyfin's path
# Dashboard → Libraries → Movies → Edit → Path
```

---

### Issue: Container Can't Access File

**Error in container:**
```
ffmpeg: /data/movies/film.mkv: No such file or directory
```

**Causes:**
1. **Wrong volume mount:** Path not mapped correctly
2. **Path translation issue:** Container path doesn't match host path

**Fix:**
```bash
# 1. Check volume mounts
docker inspect srgan-upscaler | grep -A 10 "Mounts"

# 2. Test inside container
docker exec srgan-upscaler ls -lh /data/movies/

# 3. Verify docker-compose.yml
cat docker-compose.yml | grep -A 5 "volumes:"

# 4. Restart with correct mounts
docker compose down
docker compose up -d srgan-upscaler
```

---

### Issue: Output File Not Created

**Error:** No error, but output file doesn't appear

**Causes:**
1. **Output directory doesn't exist**
2. **Permission denied**
3. **Wrong UPSCALED_DIR setting**

**Fix:**
```bash
# 1. Check output directory exists
mkdir -p /mnt/media/upscaled

# 2. Check permissions
chmod 777 /mnt/media/upscaled  # Or set proper ownership

# 3. Check environment variable
docker exec srgan-upscaler env | grep UPSCALED_DIR

# 4. Verify in container
docker exec srgan-upscaler ls -lh /data/upscaled/
```

---

## Summary

### Path Flow in 3 Steps

1. **Jellyfin → Watchdog:**
   - Path sent as-is in webhook
   - Must exist on watchdog host

2. **Watchdog → Queue:**
   - Path written to queue unchanged
   - Validated before queuing

3. **Container → FFmpeg:**
   - Path accessed via volume mount
   - Docker handles translation

### Key Configuration Points

| Component | Configuration | Default |
|-----------|--------------|---------|
| Jellyfin | Library path | (varies) |
| Watchdog | `UPSCALED_DIR` | `/data/upscaled` |
| Docker | Volume mount | `/mnt/media:/data` |
| Container | `UPSCALED_DIR` | `/data/upscaled` |

### Path Requirements

✅ **Same path on Jellyfin and Watchdog host**
✅ **Volume mount includes the input path**
✅ **Output directory writable in container**
✅ **Proper permissions on all paths**

---

**Understanding the input path flow is critical for troubleshooting deployment issues!**
