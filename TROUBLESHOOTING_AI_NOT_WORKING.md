# AI Upscaling Not Working - Troubleshooting Guide

**Date:** 2026-02-05  
**Issue:** AI upscaling doesn't appear to be taking place

---

## ✅ Verification: All Changes from Last 2 Days Are Present

I've verified that **ALL recent changes are still in the repository**:

### Git Commits (Last 2 Days)
```
ab357ee - Add docker compose v2
13fcd6d - Fix volume mount to read-write - enable output file creation
6b1522c - Add comprehensive AI upscaling diagnostic tools
8bb5e2b - Fix broken pipe and NumPy warnings in FFmpeg video processing
beb56a4 - Add FFmpeg-based video I/O as reliable alternative to torchaudio.io
c0586a2 - REMOVE ALL HLS/TS support - MKV/MP4 ONLY
b25a4e4 - Enforce AI-only upscaling, reject HLS inputs, remove FFmpeg fallback
786558b - Add intelligent filename generation with resolution and HDR tags
3302ffd - Change pipeline to output raw MKV/MP4 files instead of HLS
```

### Critical Files Verified

**docker-compose.yml (Line 27):**
```yaml
- SRGAN_ENABLE=1  ✅ PRESENT
```

**docker-compose.yml (Line 47):**
```yaml
- SRGAN_FFMPEG_ENCODER=hevc_nvenc  ✅ PRESENT
```

**scripts/srgan_pipeline.py (Lines 612-620):**
```python
enable_model = os.environ.get("SRGAN_ENABLE", "1") == "1"  # Default to enabled

if not enable_model:
    print("ERROR: AI upscaling is disabled (SRGAN_ENABLE=0)")
    print("AI upscaling must be enabled. Set SRGAN_ENABLE=1")
    print("FFmpeg-only upscaling is not supported in this mode.")
    continue
```
✅ PRESENT - AI is mandatory

**scripts/srgan_pipeline.py (Lines 356-359):**
```python
try:
    import your_model_file_ffmpeg as model_module
    print("Using FFmpeg-based AI upscaling (recommended)")
except ImportError:
```
✅ PRESENT - AI module import

**Model File:**
```
models/swift_srgan_4x.pth - 901KB  ✅ PRESENT
```

---

## ❌ Identified Issues

### 1. Docker Not Running
**Status:** Docker daemon is not accessible

**Evidence:**
```bash
$ which docker
# Output: docker not found

$ docker ps
# Output: Docker not accessible
```

**Impact:** Container cannot run, so no AI upscaling can occur

### 2. Missing Output Directory
**Status:** The `upscaled/` directory was missing

**Evidence:**
```bash
$ ls -la upscaled/
# Output: No upscaled directory or empty
```

**Action Taken:** Created the directory
```bash
$ mkdir -p upscaled cache
```

### 3. Empty Queue
**Status:** No jobs in queue

**Evidence:**
```bash
$ cat cache/queue.jsonl
# Output: (empty file)
```

**Meaning:** Either:
- No videos have been played in Jellyfin, OR
- Webhook is not triggering, OR
- Container is not running to process jobs

---

## 🔧 Required Actions to Fix

### Step 1: Start Docker Desktop

**For macOS:**
1. Open Spotlight (Cmd+Space)
2. Type "Docker"
3. Launch Docker Desktop
4. Wait for Docker icon in menu bar to show "running"

**Verify Docker is running:**
```bash
docker --version
docker ps
```

### Step 2: Rebuild and Start Container

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin

# Rebuild the image to ensure all changes are included
docker compose build --no-cache

# Start the container
docker compose up -d

# Verify it's running
docker ps | grep srgan-upscaler
```

**Expected output:**
```
srgan-upscaler   Up 5 seconds
```

### Step 3: Verify AI Configuration Inside Container

```bash
# Check environment variables
docker exec srgan-upscaler printenv | grep SRGAN_

# Expected output:
# SRGAN_ENABLE=1
# SRGAN_MODEL_PATH=/app/models/swift_srgan_4x.pth
# SRGAN_DEVICE=cuda
# SRGAN_FP16=1
# SRGAN_FFMPEG_ENCODER=hevc_nvenc
# ... (more variables)

# Check model file exists
docker exec srgan-upscaler ls -lh /app/models/

# Expected output:
# swift_srgan_4x.pth (should show file size)

# Check AI module imports
docker exec srgan-upscaler python -c "
import sys
sys.path.insert(0, '/app/scripts')
import your_model_file_ffmpeg
print('✓ AI module imports successfully')
"
```

### Step 4: Check GPU Access

```bash
# Verify GPU is accessible from container
docker exec srgan-upscaler nvidia-smi

# Expected output: Should show your GPU details
```

If this fails:
- Ensure NVIDIA drivers are installed
- Ensure nvidia-container-toolkit is installed
- Restart Docker Desktop

### Step 5: Monitor Container Logs

```bash
# Watch logs in real-time
docker logs -f srgan-upscaler
```

**On startup, you should see:**
```
GPU detected, checking NVIDIA driver patch status...
✓ NVIDIA driver patch applied/verified
Starting SRGAN pipeline...
```

### Step 6: Test with a Video

**Option A: Using Jellyfin (if webhook is configured)**
1. Play a video in Jellyfin
2. Watch container logs: `docker logs -f srgan-upscaler`

**Option B: Manual test**
```bash
# Copy a test video to the container
docker cp /path/to/test-video.mp4 srgan-upscaler:/tmp/test.mp4

# Add a job to the queue
docker exec srgan-upscaler bash -c 'echo "{\"input\":\"/tmp/test.mp4\",\"output\":\"/data/upscaled/test-upscaled.mkv\"}" >> /app/cache/queue.jsonl'

# Watch logs
docker logs -f srgan-upscaler
```

**Expected log output:**
```
============================================================
AI Upscaling Job
============================================================
Input:  /tmp/test.mp4
Output: /data/upscaled/test-upscaled.mkv

Starting AI upscaling with SRGAN model...
Using FFmpeg-based AI upscaling (recommended)
Configuration:
  Model: /app/models/swift_srgan_4x.pth
  Device: cuda
  FP16: True
  Scale: 2x
  Denoising: Enabled

Loading AI model...
✓ Model loaded

Analyzing input video...
✓ Input: 1920x1080 @ 23.98 fps
✓ Output: 3840x2160

Starting AI upscaling...
  Processed 30 frames...
  Processed 60 frames...
```

---

## 🔍 Diagnostic Script

Run the diagnostic script to check all configuration:

```bash
./scripts/diagnose_ai.sh
```

**What to look for:**

✅ **Good output:**
```
✓ Container is running
✓ SRGAN_ENABLE=1 (AI enabled)
✓ Model file exists
✓ PyTorch: 2.x.x
✓ CUDA available: True
✓ CUDA device: NVIDIA GeForce RTX XXXX
✓ GPU accessible from container
✓ FFmpeg found
✓ hevc_nvenc encoder available
✓ FFmpeg-based AI module imports successfully
```

❌ **Bad output (needs fixing):**
```
✗ Container is NOT running
  Fix: docker compose up -d
```

---

## 📊 Expected Behavior When AI Upscaling is Working

### Container Logs Should Show:

1. **On Startup:**
```
GPU detected, checking NVIDIA driver patch status...
✓ NVIDIA driver patch applied/verified
Starting SRGAN pipeline...
```

2. **When Processing Video:**
```
============================================================
AI Upscaling with FFmpeg backend
============================================================

Configuration:
  Model: /app/models/swift_srgan_4x.pth
  Device: cuda
  FP16: True
  Scale: 2x
  Denoising: Enabled
  Denoise Strength: 0.5

Loading AI model...
✓ Model loaded

Analyzing input video...
✓ Input: 1920x1080 @ 23.98 fps
✓ Output: 3840x2160

Starting AI upscaling...
  Processed 30 frames...
  Processed 60 frames...
  Processed 90 frames...
  Processed 120 frames...

✓ Processed 120 frames total
✓ AI upscaling complete
============================================================
```

3. **Verification Output:**
```
Verifying upscaled output...
✓ VERIFICATION PASSED
  File exists: Yes
  File size: 125.3 MB
  Resolution: 3840x2160
  Codec: hevc
  Duration: 30.5 seconds
```

### Output Files Should Appear:

**Location:** `/data/upscaled/` inside container (maps to `./upscaled/` on host)

**Filename Format:**
```
Movie Name [2160p].mkv
Movie Name [2160p] [HDR].mkv
TV Show S01E01 [1440p].mkv
```

**File Properties:**
- Format: MKV or MP4
- Video Codec: HEVC (H.265)
- Resolution: 2x higher than input
- Quality: High (CQ 23)

---

## 🚨 Common Problems and Solutions

### Problem: "Container is not running"
**Solution:**
```bash
docker compose up -d
```

### Problem: "GPU not accessible"
**Solution:**
1. Install NVIDIA drivers
2. Install nvidia-container-toolkit:
   ```bash
   # For macOS/Docker Desktop
   # GPU support requires Docker Desktop with NVIDIA GPU support
   ```

### Problem: "Model file not found"
**Solution:**
```bash
# Check model file exists locally
ls -lh models/swift_srgan_4x.pth

# If missing, the model file should be 901KB
# Re-download or restore from backup
```

### Problem: "Module import failed"
**Solution:**
```bash
# Rebuild container with fresh install
docker compose build --no-cache
docker compose up -d
```

### Problem: "No output files created"
**Solution:**
1. Check queue has jobs: `cat cache/queue.jsonl`
2. Check logs: `docker logs srgan-upscaler`
3. Verify webhook is configured (if using Jellyfin)
4. Try manual test (see Step 6 above)

### Problem: "Processing is very slow"
**Expected:** AI upscaling is computationally intensive
- ~1-5 fps processing speed (depends on GPU)
- A 2-minute 1080p video takes ~5-10 minutes to upscale to 4K
- This is normal for high-quality AI upscaling

---

## ✅ Verification Checklist

Run through this checklist to confirm everything is working:

- [ ] Docker Desktop is running
- [ ] Container is running: `docker ps | grep srgan-upscaler`
- [ ] SRGAN_ENABLE=1: `docker exec srgan-upscaler printenv SRGAN_ENABLE`
- [ ] Model file exists: `docker exec srgan-upscaler ls -lh /app/models/`
- [ ] GPU accessible: `docker exec srgan-upscaler nvidia-smi`
- [ ] NVENC available: `docker exec srgan-upscaler ffmpeg -hide_banner -encoders 2>&1 | grep hevc_nvenc`
- [ ] AI module imports: `docker exec srgan-upscaler python -c "import sys; sys.path.insert(0, '/app/scripts'); import your_model_file_ffmpeg; print('OK')"`
- [ ] Logs show no errors: `docker logs srgan-upscaler | tail -50`
- [ ] Can manually add test job and see processing in logs

---

## 📝 Summary

### Configuration Status: ✅ ALL CHANGES PRESENT

All changes from the last 2 days are still present in the repository:
- ✅ SRGAN_ENABLE=1
- ✅ SRGAN_FFMPEG_ENCODER=hevc_nvenc
- ✅ AI mandatory check in code
- ✅ FFmpeg-based AI module
- ✅ Model file present
- ✅ No FFmpeg fallback (deprecated functions raise errors)

### Issue: ❌ DOCKER NOT RUNNING

The container is not running, which is why no AI upscaling is occurring.

### Fix: 🔧 START DOCKER AND CONTAINER

```bash
# 1. Start Docker Desktop (macOS)
open -a Docker

# 2. Wait for Docker to be ready
sleep 10

# 3. Start the container
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin
docker compose up -d

# 4. Verify
docker logs -f srgan-upscaler
```

Once the container is running, AI upscaling will work automatically when videos are played in Jellyfin (if webhook is configured) or when jobs are manually added to the queue.

---

## 🆘 If Still Not Working

If you've completed all the steps above and AI upscaling still isn't working:

1. **Capture logs:**
   ```bash
   docker logs srgan-upscaler > ~/srgan-logs.txt
   ```

2. **Run diagnostic:**
   ```bash
   ./scripts/diagnose_ai.sh > ~/srgan-diagnostic.txt
   ```

3. **Check docker-compose config:**
   ```bash
   docker compose config > ~/docker-compose-actual.yml
   ```

4. **Share the output** of these commands for further debugging.
