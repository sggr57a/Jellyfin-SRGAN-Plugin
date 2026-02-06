# AI Upscaling Diagnostic & Verification Guide

## 🔍 Complete System Check

Run the comprehensive diagnostic script:

```bash
cd /root/Jellyfin-SRGAN-Plugin
./scripts/diagnose_ai.sh
```

This checks:
1. ✅ Container running
2. ✅ SRGAN_ENABLE=1
3. ✅ Model file exists
4. ✅ PyTorch & CUDA working
5. ✅ GPU accessible
6. ✅ FFmpeg & NVENC available
7. ✅ AI module imports
8. ✅ Queue status
9. ✅ Recent AI activity
10. ✅ Full configuration

---

## 🎯 Key Verification Points

### 1. SRGAN_ENABLE Must Be 1

```bash
docker exec srgan-upscaler printenv SRGAN_ENABLE
# Should show: 1
```

**If 0:** Edit `docker-compose.yml` line 27:
```yaml
- SRGAN_ENABLE=1  # Must be 1
```

---

### 2. Model File Must Exist

```bash
docker exec srgan-upscaler ls -lh /app/models/swift_srgan_4x.pth
# Should show: ~900KB file
```

**If missing:**
```bash
cd /root/Jellyfin-SRGAN-Plugin
./scripts/setup_model.sh
```

---

### 3. GPU Must Be Accessible

```bash
docker exec srgan-upscaler nvidia-smi
# Should show GPU info
```

**If error:** Check nvidia-container-toolkit:
```bash
sudo apt install nvidia-container-toolkit
sudo systemctl restart docker
docker compose restart
```

---

### 4. AI Module Must Import

```bash
docker exec srgan-upscaler python -c "
import sys
sys.path.insert(0, '/app/scripts')
import your_model_file_ffmpeg
print('OK')
"
# Should show: OK
```

---

### 5. Queue Must Be Clear

```bash
cat /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl
# Should be empty or only have .mkv/.mp4 outputs
```

**If has .ts outputs:**
```bash
./scripts/clear_queue.sh
```

---

## 📋 Complete Verification Checklist

Run through this checklist:

- [ ] Container running: `docker ps | grep srgan-upscaler`
- [ ] SRGAN_ENABLE=1: `docker exec srgan-upscaler printenv SRGAN_ENABLE`
- [ ] Model exists: `docker exec srgan-upscaler ls /app/models/swift_srgan_4x.pth`
- [ ] CUDA available: `docker exec srgan-upscaler python -c "import torch; print(torch.cuda.is_available())"`
- [ ] GPU accessible: `docker exec srgan-upscaler nvidia-smi`
- [ ] NVENC available: `docker exec srgan-upscaler ffmpeg -encoders 2>&1 | grep hevc_nvenc`
- [ ] AI module imports: `docker exec srgan-upscaler python -c "import sys; sys.path.insert(0,'/app/scripts'); import your_model_file_ffmpeg"`
- [ ] Queue clear: `cat cache/queue.jsonl` (empty or no .ts files)
- [ ] Volume mounted: `docker exec srgan-upscaler ls /mnt/media`

---

## 🧪 Test Upscaling

### Step-by-Step Test

```bash
# 1. Clear queue
cd /root/Jellyfin-SRGAN-Plugin
./scripts/clear_queue.sh

# 2. Restart container (fresh state)
docker compose restart srgan-upscaler

# 3. Watch logs in real-time
docker logs -f srgan-upscaler

# 4. Play a video in Jellyfin
# (in another terminal or browser)

# 5. Look for these log lines:
```

**Expected Log Output:**

```
================================================================================
AI Upscaling Job
================================================================================
Input:  /mnt/media/MOVIES/Movie [1080p].mkv
Output: /mnt/media/MOVIES/Movie_upscaled.mkv

Starting AI upscaling with SRGAN model...
Using FFmpeg-based AI upscaling (recommended)  ← MUST SEE THIS

================================================================================
AI Upscaling with FFmpeg backend
================================================================================

Configuration:
  Model: /app/models/swift_srgan_4x.pth        ← MUST SEE THIS
  Device: cuda                                  ← MUST BE cuda
  FP16: True
  Scale: 2x
  Denoising: Enabled
  Denoise Strength: 0.5

Loading AI model...
✓ Model loaded                                  ← MUST SEE THIS

Analyzing input video...
✓ Input: 1920x1080 @ 23.98 fps
✓ Output: 3840x2160

Starting AI upscaling...
  Processed 30 frames...                        ← MUST SEE PROGRESS
  Processed 60 frames...
  Processed 90 frames...
```

---

## 🚨 If AI Is NOT Being Used

### Symptoms

**NOT using AI:**
```
✗ No "Using FFmpeg-based AI upscaling" message
✗ No "Configuration: Model: ..." message
✗ No "Loading AI model..." message
✗ No "Processed X frames..." progress
✗ Very fast processing (<2x realtime)
```

**Using AI:**
```
✓ "Using FFmpeg-based AI upscaling (recommended)"
✓ "Configuration: Model: /app/models/swift_srgan_4x.pth"
✓ "Loading AI model..."
✓ "Processed 30 frames..." (slow progress)
✓ GPU usage high (nvidia-smi shows Python using GPU)
✓ Processing 2-10x realtime (slow but high quality)
```

---

## 🔧 Troubleshooting

### Issue: "Could not import AI model"

```bash
# Check Python can find module
docker exec srgan-upscaler python -c "
import sys
import os
sys.path.insert(0, '/app/scripts')
print('Python path:', sys.path)
print('Scripts dir:', os.listdir('/app/scripts'))
"

# Should show your_model_file_ffmpeg.py in list
```

---

### Issue: "Model file not found"

```bash
# Check model path
docker exec srgan-upscaler printenv SRGAN_MODEL_PATH
# Should show: /app/models/swift_srgan_4x.pth

# Check file exists
docker exec srgan-upscaler ls -lh /app/models/
# Should show: swift_srgan_4x.pth (~900KB)

# If missing, download it
cd /root/Jellyfin-SRGAN-Plugin
./scripts/setup_model.sh
```

---

### Issue: GPU not accessible

```bash
# Check GPU visible
docker exec srgan-upscaler nvidia-smi

# If fails, check host
nvidia-smi

# Check container GPU access
docker exec srgan-upscaler python -c "
import torch
print('CUDA available:', torch.cuda.is_available())
print('CUDA device count:', torch.cuda.device_count())
if torch.cuda.is_available():
    print('CUDA device:', torch.cuda.get_device_name(0))
"
```

---

### Issue: NVENC not available

```bash
# Check encoder
docker exec srgan-upscaler ffmpeg -hide_banner -encoders 2>&1 | grep nvenc

# Should show:
# V..... hevc_nvenc
# V..... h264_nvenc

# If not, will use CPU encoding (slower but works)
```

---

## 📊 Performance Indicators

### AI Upscaling IS Working

| Indicator | Expected Value |
|-----------|----------------|
| Processing speed | 2-10x realtime (slow) |
| GPU usage | 80-100% during processing |
| VRAM usage | 4-12GB |
| CPU usage | Low (GPU doing work) |
| Progress updates | "Processed X frames..." |
| Log messages | "AI", "Model", "SRGAN" |

### AI NOT Working (FFmpeg only)

| Indicator | Value |
|-----------|-------|
| Processing speed | ~1x realtime (fast) |
| GPU usage | <20% |
| VRAM usage | <500MB |
| CPU usage | High |
| Progress updates | None |
| Log messages | No AI mentions |

---

## 🎯 Summary

**Quick Diagnostic:**
```bash
./scripts/diagnose_ai.sh
```

**Quick Fix:**
```bash
# If AI not working:
cd /root/Jellyfin-SRGAN-Plugin

# 1. Clear old jobs
./scripts/clear_queue.sh

# 2. Verify configuration
grep "SRGAN_ENABLE" docker-compose.yml
# Should show: - SRGAN_ENABLE=1

# 3. Verify model exists
ls -lh models/swift_srgan_4x.pth

# 4. Restart container
docker compose restart srgan-upscaler

# 5. Test
# Play video, watch logs:
docker logs -f srgan-upscaler
```

**Must See in Logs:**
1. "Using FFmpeg-based AI upscaling"
2. "Configuration: Model: /app/models/swift_srgan_4x.pth"
3. "Device: cuda"
4. "✓ Model loaded"
5. "Processed 30 frames..."

**If you don't see these, AI is NOT running!**
