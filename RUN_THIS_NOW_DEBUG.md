# 🚀 RUN THIS NOW - AI Debugging Quick Start

## Your Issue
AI model is not being used when playing videos. NVIDIA encoding is not active.

---

## Step 1: Pull Latest Code (30 seconds)

```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
```

**Expected:** "Already up to date" or files updated

---

## Step 2: Run Diagnostic (1 minute)

```bash
./scripts/debug_pipeline.sh
```

**Look for:**
- ✓ = Working correctly
- ✗ = Problem found
- ⚠ = Warning

**Common problems:**
- ✗ Pipeline process NOT running → Container crashed
- ✗ Model file MISSING → Need to download
- ✗ GPU NOT accessible → Need to fix Docker/NVIDIA setup
- Jobs in queue: 0 → Watchdog not queueing jobs

---

## Step 3: Fix Based on Diagnostic

### If "Pipeline process NOT running":
```bash
docker logs srgan-upscaler --tail 100
# Look for errors, then rebuild:
docker compose down
docker compose build --no-cache
docker compose up -d
```

### If "Model file MISSING":
```bash
./scripts/setup_model.sh
```

### If "GPU NOT accessible":
```bash
systemctl restart docker
docker compose down
docker compose up -d
docker exec srgan-upscaler nvidia-smi
```

### If "Jobs in queue: 0" (Watchdog not working):
```bash
journalctl -u srgan-watchdog-api -n 50
systemctl restart srgan-watchdog-api
```

---

## Step 4: Manual Test (10-30 minutes depending on video)

```bash
./scripts/test_manual_queue.sh
```

**What it does:**
1. Finds a test video automatically
2. Clears queue
3. Queues test job
4. Watches logs in real-time

**You should see:**
```
🚀 JOB STARTED
🧠 Loading AI model...
✓ Model loaded
🔍 Analyzing video...
⚙️ Processing frames...
📊 Processed 30 frames...
📊 Processed 60 frames...
...
✅ AI upscaling complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓✓✓ VERIFICATION PASSED ✓✓✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
╔════════════════════════════════════════════════════════════════╗
║                     🎉 SUCCESS 🎉                               ║
╚════════════════════════════════════════════════════════════════╝
```

**If AI is working:**
- You'll see frame processing (slow, takes time)
- You'll see "Loading AI model"
- Output file will be larger and 2160p resolution

**If AI is NOT working:**
- Will fail immediately with error
- Or will skip and show reason
- Check error messages

---

## Step 5: Test with Jellyfin (if manual test works)

```bash
# In one terminal, watch logs:
docker logs -f srgan-upscaler

# In Jellyfin browser:
# - Play any video (1080p or lower recommended)
# - Even 1 second of playback will trigger it

# Watch the logs terminal for:
# - "AI Upscaling Job" message
# - "Loading AI model"
# - Frame processing
```

---

## 🎯 Quick Diagnosis

### AI IS Working If You See:
- ✅ "Using FFmpeg-based AI upscaling (recommended)"
- ✅ "Loading AI model..."
- ✅ "Processed X frames..." (many lines)
- ✅ Takes 15-30+ minutes for a 2-hour 1080p movie
- ✅ Output resolution is 3840x2160
- ✅ Output codec is hevc

### AI is NOT Working If You See:
- ❌ No "Loading AI model" message
- ❌ Completes in < 2 minutes for large file
- ❌ No frame processing messages
- ❌ Error about model not found
- ❌ CUDA not available errors

---

## 📋 Complete Reset (if nothing works)

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Stop everything
docker compose down
systemctl stop srgan-watchdog-api

# Clear cache
rm -rf ./cache/*
rm -rf ./upscaled/*

# Pull latest
git pull origin main

# Rebuild
docker compose build --no-cache

# Get model
./scripts/setup_model.sh

# Start
docker compose up -d
systemctl start srgan-watchdog-api

# Test
./scripts/debug_pipeline.sh
./scripts/test_manual_queue.sh
```

---

## 🔍 What to Report Back

After running the diagnostic, tell me:

1. **Diagnostic results:**
   - Which checks passed (✓)?
   - Which checks failed (✗)?

2. **Container logs (if pipeline not running):**
   ```bash
   docker logs srgan-upscaler --tail 50
   ```

3. **Manual test result:**
   - Did it start?
   - Did you see "Loading AI model"?
   - Did you see frame processing?
   - Did it complete successfully?

4. **Queue status:**
   ```bash
   cat ./cache/queue.jsonl
   ```

---

## Expected Results

### Diagnostic (debug_pipeline.sh)
```
✓ srgan-upscaler container is running
✓ Pipeline process is running
✓ Queue file exists (Jobs: 0)
✓ Watchdog API service is running
✓ GPU is accessible
✓ Model file exists (901K)
✓ SRGAN_ENABLE: 1
✓ FFmpeg-based AI module imports successfully
✓ PyTorch 2.4.0 available
✓ CUDA available: True
✓ /mnt/media is mounted (Write: YES)

Results: 10/10 passed
```

### Manual Test (test_manual_queue.sh)
```
Should take 15-30 minutes for a 2-hour movie
Should show continuous frame processing
Should end with SUCCESS banner
Output file should be ~2-4x larger than input
Output file should have 2160p in filename
```

---

## 💡 Pro Tips

1. **Don't wait for Jellyfin** - Test manually first with `test_manual_queue.sh`
2. **Check container logs frequently** - `docker logs -f srgan-upscaler`
3. **One video at a time** - Don't queue multiple, test one first
4. **Use small test file** - Start with a 5-10 minute video clip if possible
5. **GPU memory** - Make sure no other GPU processes are running

---

## Summary

**Three scripts to run:**
1. `./scripts/debug_pipeline.sh` - Find the problem
2. Apply fixes from the diagnostic output
3. `./scripts/test_manual_queue.sh` - Verify AI works

**Success = Seeing frame processing progress**

If you see frame-by-frame processing, AI is working! 🎉
