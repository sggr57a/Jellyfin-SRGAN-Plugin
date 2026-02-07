# 🔧 AI MODEL NOT RUNNING - DEBUG & FIX GUIDE

## Problem
AI model is not being used when playing videos in Jellyfin. NVIDIA encoding is not active.

## Root Cause Analysis

The issue is likely **NOT** with the code itself (which is correct), but with:
1. **Pipeline not receiving jobs** - Watchdog API may not be queueing jobs
2. **Pipeline crashed on startup** - Import errors or missing dependencies
3. **Jobs queued but not processed** - Pipeline may be stuck or waiting

---

## 🔍 Step 1: Run Comprehensive Diagnostic

```bash
cd /root/Jellyfin-SRGAN-Plugin
./scripts/debug_pipeline.sh
```

This checks:
- ✓ Container status
- ✓ Pipeline process running
- ✓ Queue file status
- ✓ Watchdog API status
- ✓ GPU access
- ✓ Model file exists
- ✓ Environment variables
- ✓ Recent logs
- ✓ AI module imports
- ✓ Volume mounts

**Expected output:** All checks should pass (✓)

---

## 🧪 Step 2: Manual Test

Test the pipeline directly by manually queueing a job:

```bash
./scripts/test_manual_queue.sh
```

This will:
1. Find a test video
2. Clear the queue
3. Queue a test job
4. Watch logs in real-time with highlighting

**Expected behavior:**
- Should see "🚀 JOB STARTED"
- Should see "🧠 Loading AI model"
- Should see "⚙️ Processing frames"
- Should see "✓✓✓ SUCCESS ✓✓✓"

---

## 🐛 Common Issues & Fixes

### Issue 1: Pipeline Not Running

**Symptoms:**
```
✗ Pipeline process is NOT running
```

**Check logs:**
```bash
docker logs srgan-upscaler --tail 100
```

**Common causes:**
- Import error (missing Python module)
- Model file missing
- GPU not accessible

**Fix:**
```bash
# Rebuild container
docker compose down
docker compose build --no-cache
docker compose up -d

# Check logs again
docker logs -f srgan-upscaler
```

---

### Issue 2: No Jobs Being Queued

**Symptoms:**
```
Jobs in queue: 0
(even after playing videos)
```

**Check watchdog:**
```bash
systemctl status srgan-watchdog-api
journalctl -u srgan-watchdog-api -n 50
```

**Look for:**
- "Playback started" messages
- "Queuing upscaling job" messages
- API connection errors

**Fix:**
```bash
# Restart watchdog
systemctl restart srgan-watchdog-api

# Watch logs
journalctl -u srgan-watchdog-api -f
```

---

### Issue 3: Jobs Queued But Not Processed

**Symptoms:**
```
Jobs in queue: 5
(but nothing happening in logs)
```

**Check:**
```bash
# View queue
cat ./cache/queue.jsonl

# Check pipeline logs
docker logs -f srgan-upscaler
```

**Possible causes:**
- Pipeline stuck on previous job
- HLS/TS files in queue (should be rejected)
- Input files don't exist

**Fix:**
```bash
# Clear queue and restart
./scripts/clear_queue.sh
docker restart srgan-upscaler
```

---

### Issue 4: AI Model File Missing

**Symptoms:**
```
✗ Model file is MISSING
ERROR: Could not load model
```

**Fix:**
```bash
./scripts/setup_model.sh
```

This will download the SRGAN model (swift_srgan_4x.pth)

---

### Issue 5: GPU Not Accessible

**Symptoms:**
```
✗ GPU is NOT accessible from container
CUDA not available
```

**Fix:**
```bash
# Check nvidia-docker
dpkg -l | grep nvidia-docker2

# Restart Docker daemon
systemctl restart docker

# Recreate container
docker compose down
docker compose up -d

# Verify GPU
docker exec srgan-upscaler nvidia-smi
```

---

### Issue 6: Volume Mount Read-Only

**Symptoms:**
```
✗ Write permission: NO
ERROR: Permission denied
```

**Check docker-compose.yml:**
```yaml
volumes:
  - /mnt/media:/mnt/media:rw  # Must have :rw
```

**Fix:**
```bash
# Edit docker-compose.yml if needed
docker compose down
docker compose up -d
```

---

## 📊 Verify AI is Actually Running

Once you've fixed issues, verify AI is working:

### 1. Check Environment
```bash
docker exec srgan-upscaler env | grep SRGAN
```

Should show:
```
SRGAN_ENABLE=1
SRGAN_MODEL_PATH=/app/models/swift_srgan_4x.pth
SRGAN_DEVICE=cuda
SRGAN_FFMPEG_ENCODER=hevc_nvenc
```

### 2. Test AI Module Import
```bash
docker exec srgan-upscaler python3 -c "
import sys
sys.path.insert(0, '/app/scripts')
import your_model_file_ffmpeg
import torch
print('PyTorch:', torch.__version__)
print('CUDA:', torch.cuda.is_available())
print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')
"
```

Should show:
```
PyTorch: 2.4.0+cu121
CUDA: True
GPU: NVIDIA GeForce RTX 4090 (or your GPU)
```

### 3. Monitor Real-Time Processing
```bash
# Play a video in Jellyfin, then:
docker logs -f srgan-upscaler
```

Look for these key messages:
```
================================================================================
AI Upscaling Job
================================================================================
Input:  /mnt/media/MOVIES/Movie [1080p].mkv
Output: /mnt/media/MOVIES/Movie_upscaled.mkv

Starting AI upscaling with SRGAN model...
Using FFmpeg-based AI upscaling (recommended)  ← CRITICAL: Must see this

Loading AI model...
✓ Model loaded

Analyzing input video...
✓ Input: 1920x1080 @ 23.98 fps
✓ Output: 3840x2160

Starting AI upscaling...
  Processed 30 frames...   ← CRITICAL: Must see frame progress
  Processed 60 frames...
  ...
  
✓ AI upscaling complete

Verifying upscaled output...
✓ VERIFICATION PASSED
  Resolution: 3840x2160   ← CRITICAL: Verify upscaled resolution
  Codec: hevc             ← CRITICAL: Verify NVIDIA encoder used
  
✓✓✓ AI UPSCALING SUCCESSFULLY COMPLETED ✓✓✓
```

---

## 🎯 What You Should See

### Correct Behavior:
1. ✅ "Using FFmpeg-based AI upscaling (recommended)"
2. ✅ "Loading AI model..."
3. ✅ "Processed X frames..." (progress updates)
4. ✅ "Codec: hevc" (NVIDIA encoder)
5. ✅ "Resolution: 3840x2160" (upscaled resolution)
6. ✅ Output file created in same directory

### Incorrect Behavior (AI NOT running):
- ❌ No "Loading AI model" message
- ❌ No frame processing updates
- ❌ Immediate completion (< 1 minute for large file)
- ❌ Output resolution same as input
- ❌ Error messages about model not found

---

## 🔧 Nuclear Option: Complete Reset

If nothing works, completely reset:

```bash
cd /root/Jellyfin-SRGAN-Plugin

# 1. Stop everything
docker compose down
systemctl stop srgan-watchdog-api

# 2. Clear cache
rm -rf ./cache/*
rm -rf ./upscaled/*

# 3. Pull latest code
git pull origin main

# 4. Rebuild from scratch
docker compose build --no-cache

# 5. Verify model
./scripts/setup_model.sh

# 6. Start everything
docker compose up -d
systemctl start srgan-watchdog-api

# 7. Run diagnostics
./scripts/debug_pipeline.sh

# 8. Manual test
./scripts/test_manual_queue.sh
```

---

## 📝 Expected Timeline

For a 1080p movie (2 hours):
- **With AI upscaling:** 15-30 minutes (depending on GPU)
- **Without AI (wrong):** < 2 minutes (FFmpeg only)

If upscaling completes in < 5 minutes for a feature film, **AI is NOT being used**.

---

## 📞 Get Help

If still not working after all steps:

1. **Run diagnostics:**
   ```bash
   ./scripts/debug_pipeline.sh > debug_output.txt
   ./scripts/diagnose_ai.sh >> debug_output.txt
   ```

2. **Capture logs:**
   ```bash
   docker logs srgan-upscaler --tail 500 > container_logs.txt
   journalctl -u srgan-watchdog-api -n 200 > watchdog_logs.txt
   ```

3. **Check queue:**
   ```bash
   cat ./cache/queue.jsonl > queue_status.txt
   ```

4. **Review output files** and paste relevant sections.

---

## Summary

**Tools created:**
- `debug_pipeline.sh` - 10-point diagnostic check
- `test_manual_queue.sh` - Manual job queueing and monitoring
- `diagnose_ai.sh` - AI-specific verification (already exists)

**Process:**
1. Run `debug_pipeline.sh` to identify issues
2. Fix any problems found (container, GPU, model, etc.)
3. Run `test_manual_queue.sh` to verify AI works
4. Play video in Jellyfin and monitor logs
5. Verify output file has correct resolution and codec

**Success criteria:**
- See "Loading AI model" in logs
- See frame processing progress
- Processing takes appropriate time (not instant)
- Output resolution is upscaled (2160p)
- Output codec is hevc (NVIDIA encoder)
