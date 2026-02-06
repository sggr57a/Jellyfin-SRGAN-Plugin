# CRITICAL: Run These Commands NOW

## 🚨 Quick Diagnostic Steps

Run these commands on your server to verify AI upscaling:

---

## Step 1: Run Diagnostic

```bash
cd /root/Jellyfin-SRGAN-Plugin
./scripts/diagnose_ai.sh
```

**Look for ✓ on ALL items!**

---

## Step 2: Clear Queue (CRITICAL!)

```bash
./scripts/clear_queue.sh
```

**This removes old .ts jobs that are causing errors!**

---

## Step 3: Restart Container

```bash
docker compose restart srgan-upscaler
docker compose restart srgan-watchdog-api
```

---

## Step 4: Test Upscaling

```bash
# In one terminal, watch logs:
docker logs -f srgan-upscaler

# In Jellyfin, play a video
# You MUST see these log lines:
```

**MUST SEE in logs:**

```
Using FFmpeg-based AI upscaling (recommended)  ← Line 1

Configuration:                                  ← Line 2
  Model: /app/models/swift_srgan_4x.pth
  Device: cuda
  FP16: True
  Scale: 2x

Loading AI model...                             ← Line 3
✓ Model loaded

Analyzing input video...                        ← Line 4
✓ Input: 1920x1080 @ 23.98 fps
✓ Output: 3840x2160

Starting AI upscaling...                        ← Line 5
  Processed 30 frames...
  Processed 60 frames...
```

---

## 🚨 If You DON'T See These Lines

### Scenario 1: No logs at all

**Cause:** Container not processing job

**Fix:**
```bash
# Check watchdog is running
docker logs srgan-watchdog-api | tail -20

# Should show:
# "✓ AI upscaling job queued"
# "Starting srgan-upscaler container..."
```

---

### Scenario 2: "ERROR: AI upscaling is disabled"

**Logs show:**
```
ERROR: AI upscaling is disabled (SRGAN_ENABLE=0)
```

**Fix:**
```bash
# Edit docker-compose.yml line 27
vi docker-compose.yml
# Change to: SRGAN_ENABLE=1

# Restart
docker compose down && docker compose up -d
```

---

### Scenario 3: "ERROR: Could not import AI model"

**Logs show:**
```
ERROR: Could not import AI model: ...
```

**Fix:**
```bash
# Rebuild container
docker compose build --no-cache srgan-upscaler
docker compose restart srgan-upscaler
```

---

### Scenario 4: "Unsupported output format: .ts"

**Logs show:**
```
ValueError: Unsupported output format: .ts
```

**Fix:**
```bash
# Clear queue (has old .ts jobs)
./scripts/clear_queue.sh
docker compose restart srgan-watchdog-api
```

---

## 📊 Performance Check

### Check GPU Usage During Processing

```bash
# In another terminal while video is upscaling:
watch -n 1 nvidia-smi
```

**If AI is working:**
```
|   0  RTX 4090   | Python   95%  10GB / 24GB |  350W |
                     ^^^^^^   ^^^  ^^^^^^^^^^^
                     Process  GPU  VRAM usage
```

**If AI NOT working:**
```
|   0  RTX 4090   | -        0%   100MB / 24GB |  50W |
                     ^        ^    ^^^^^^^^^^^^^
                     No proc  Idle Minimal
```

---

## ✅ Success Indicators

If AI upscaling is working, you'll see:

1. ✅ "Using FFmpeg-based AI upscaling" in logs
2. ✅ "Device: cuda" in configuration
3. ✅ "✓ Model loaded" message
4. ✅ "Processed X frames..." progress updates (every 30 frames)
5. ✅ Processing takes 2-10x realtime (slow but high quality)
6. ✅ GPU usage 80-100% (nvidia-smi)
7. ✅ VRAM usage 4-12GB
8. ✅ Python process visible in nvidia-smi
9. ✅ Output file has intelligent name: `Movie [2160p].mkv`
10. ✅ Output file size ~2x input (due to higher resolution)

---

## ❌ Failure Indicators

If AI is NOT working:

1. ❌ No "Using FFmpeg-based" message
2. ❌ No "Configuration: Model:" message
3. ❌ No "Loading AI model..." message
4. ❌ No progress updates
5. ❌ Processing very fast (<2x realtime)
6. ❌ GPU usage low (<20%)
7. ❌ VRAM usage minimal (<500MB)
8. ❌ No Python in nvidia-smi
9. ❌ Errors about .ts files
10. ❌ Errors about model import

---

## 🎯 Quick Commands Reference

```bash
# Diagnostic
./scripts/diagnose_ai.sh

# Clear queue
./scripts/clear_queue.sh

# Restart
docker compose restart srgan-upscaler

# Watch logs
docker logs -f srgan-upscaler

# Check GPU
nvidia-smi

# Check SRGAN_ENABLE
docker exec srgan-upscaler printenv SRGAN_ENABLE

# Check model
docker exec srgan-upscaler ls -lh /app/models/

# Check AI module
docker exec srgan-upscaler python -c "import sys; sys.path.insert(0,'/app/scripts'); import your_model_file_ffmpeg; print('OK')"
```

---

## 🚀 Complete Reset (If Nothing Works)

If AI still not working after diagnostic:

```bash
cd /root/Jellyfin-SRGAN-Plugin

# 1. Stop everything
docker compose down

# 2. Clear queue
./scripts/clear_queue.sh

# 3. Verify model file
ls -lh models/swift_srgan_4x.pth
# Should show ~900KB file

# 4. Verify SRGAN_ENABLE=1
grep "SRGAN_ENABLE" docker-compose.yml
# Should show: - SRGAN_ENABLE=1

# 5. Rebuild from scratch
docker compose build --no-cache srgan-upscaler

# 6. Start
docker compose up -d

# 7. Run diagnostic
./scripts/diagnose_ai.sh

# 8. Test with video
docker logs -f srgan-upscaler
# (play video in Jellyfin)
```

---

## 🎯 Expected Timeline

**For a 2-hour 1080p movie:**

- AI upscaling: 4-20 minutes (depending on GPU)
- Progress: Updates every 30 frames
- GPU: High usage throughout
- Result: High-quality 4K output

**If it finishes in <2 minutes, AI is NOT running!**
