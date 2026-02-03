# How to Verify AI Upscaling is Active

## 🎯 Quick Check

Run the automated verification script:

```bash
cd /root/Jellyfin-SRGAN-Plugin
./scripts/check_ai_active.sh
```

This will check:
- ✅ SRGAN_ENABLE setting
- ✅ Model file presence
- ✅ Log analysis for AI activity
- ✅ GPU usage patterns

---

## 📊 Manual Verification

### Method 1: Check Container Logs

```bash
docker logs srgan-upscaler | grep -i "AI\|model\|srgan"
```

**If AI is active, you'll see:**

```
AI Upscaling Configuration:
  Model: /app/models/swift_srgan_4x.pth
  Device: cuda
  FP16: True
  Scale: 4x
  Denoising: Enabled
  Denoise Strength: 0.5

Loading SRGAN model from /app/models/swift_srgan_4x.pth
Using device: cuda
Model loaded successfully
```

**If AI is NOT active (using FFmpeg), you'll see:**

```
Using streaming mode (HLS)
Starting streaming upscale:
  Input:  /mnt/media/...
  
[No mention of AI, model, or SRGAN]
```

---

### Method 2: Real-Time Log Monitoring

```bash
# Follow logs in real-time
docker logs -f srgan-upscaler
```

**AI Active - You'll see:**
```
Processing frame 45/1000...
AI inference: 23.4ms per frame
VRAM usage: 4.2GB
Denoising applied
Upscaling with SRGAN...
```

**FFmpeg Only - You'll see:**
```
frame=   45 fps=  23 q=23.0 size=1024kB time=00:00:01.80
[Just FFmpeg encoding stats, no AI mentions]
```

---

### Method 3: GPU Usage

```bash
# Watch GPU in real-time
watch -n 1 nvidia-smi
```

**AI Model Active:**
```
+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   PID   Type   Process name                            GPU Memory     |
|        123   C      python                                  4521MiB         |
|        124   C      ffmpeg                                  1024MiB         |
+-----------------------------------------------------------------------------+
```

**Indicators of AI:**
- ✅ **Python process** present (AI runs in Python)
- ✅ **High VRAM usage** (3-8GB for AI model)
- ✅ **GPU utilization** 80-95%

**FFmpeg Only:**
```
+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   PID   Type   Process name                            GPU Memory     |
|        124   C      ffmpeg                                  512MiB          |
+-----------------------------------------------------------------------------+
```

**Indicators of FFmpeg-only:**
- ❌ No Python process
- ❌ Lower VRAM usage (< 1GB)
- ❌ GPU utilization 30-50%

---

### Method 4: Check Configuration

```bash
docker compose exec srgan-upscaler printenv | grep SRGAN
```

**Should show:**
```
SRGAN_ENABLE=1              ← Must be 1 for AI
SRGAN_MODEL_PATH=/app/models/swift_srgan_4x.pth
SRGAN_DEVICE=cuda
SRGAN_FP16=1
SRGAN_SCALE_FACTOR=2.0
SRGAN_DENOISE=1             ← Denoising enabled
SRGAN_DENOISE_STRENGTH=0.5
```

If `SRGAN_ENABLE=0`, AI is **disabled**.

---

### Method 5: Check Model File

```bash
docker compose exec srgan-upscaler ls -lh /app/models/
```

**Should show:**
```
-rw-r--r-- 1 root root 16M Feb  1 10:00 swift_srgan_4x.pth
```

If model file is missing, AI **cannot run**.

---

## 🔍 Detailed Log Patterns

### AI Model Active

**Startup:**
```
Starting SRGAN pipeline...
AI Upscaling Configuration:
  Model: /app/models/swift_srgan_4x.pth
  Device: cuda
  FP16: True
  Scale: 4x
  Denoising: Enabled
  Denoise Strength: 0.5

Loading model weights...
Initializing CUDA...
Model ready
```

**During Processing:**
```
Processing: Back to the Future (1985).mp4
Input resolution: 1920x1080
Target resolution: 3840x2160 (4x)

Frame 100/5000:
  Denoise: 3.2ms
  AI upscale: 45.1ms
  Encode: 12.3ms
  Total: 60.6ms (16.5 fps)

VRAM: 4.2GB / 8GB
GPU: 87%
```

**Key phrases indicating AI:**
- "AI Upscaling Configuration"
- "Loading SRGAN model"
- "AI upscale: XX ms"
- "Denoise: XX ms"
- "Model ready"
- High VRAM numbers (3-8GB)

---

### FFmpeg Mode (No AI)

**Startup:**
```
Using streaming mode (HLS)
Starting streaming upscale:
  Input:  /mnt/media/MOVIES/...
  HLS:    ./upscaled/hls/.../stream.m3u8
  Segment duration: 6s
```

**During Processing:**
```
frame=  100 fps= 23 q=23.0 size=1024kB time=00:00:04.00 bitrate=2097.2kbits/s speed=0.92x
```

**Key indicators of FFmpeg-only:**
- "Using streaming mode" or "Using batch mode"
- No mention of "AI" or "model"
- FFmpeg frame stats only
- Lower GPU usage

---

## 🎬 Processing Speed Comparison

### AI Model
```
Processing: ~0.2-0.5x real-time
Example: 2-hour movie = 4-10 hours
GPU: 80-95% utilization
VRAM: 3-8GB
```

### FFmpeg Only
```
Processing: ~0.8-1.2x real-time
Example: 2-hour movie = 1.5-2.5 hours
GPU: 30-50% utilization
VRAM: < 1GB
```

**Much slower = AI is probably active!**

---

## 🧪 Test to Confirm

### Queue a Small Test File

```bash
# Create test job
echo '{"input":"/mnt/media/test.mp4","output":"./upscaled/test.ts","streaming":true}' >> /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl

# Watch logs immediately
docker logs -f srgan-upscaler
```

**Within first 10 seconds, you should see:**

**If AI active:**
```
AI Upscaling Configuration:
  Model: /app/models/swift_srgan_4x.pth
  ...
Loading SRGAN model...
```

**If FFmpeg only:**
```
Using streaming mode (HLS)
Starting streaming upscale:
[No AI mentions]
```

---

## 📈 Visual Comparison in Output

### Check Output Quality

```bash
# View a segment
vlc /root/Jellyfin-SRGAN-Plugin/upscaled/hls/*/segment_010.ts
```

**AI-upscaled:**
- ✅ Sharp edges
- ✅ Clear textures
- ✅ Fine details visible
- ✅ No excessive smoothing

**FFmpeg-only:**
- ⚠️ Softer edges
- ⚠️ Smooth/blurred textures
- ⚠️ Less detail
- ⚠️ More interpolated look

---

## 🎯 Summary Checklist

AI is active if:

- ✅ `SRGAN_ENABLE=1` in config
- ✅ Model file exists (16MB)
- ✅ Logs show "AI Upscaling Configuration"
- ✅ Python process using GPU
- ✅ High VRAM usage (3-8GB)
- ✅ High GPU utilization (80-95%)
- ✅ Slow processing (0.2-0.5x real-time)
- ✅ Logs mention "model" and "denoise"

AI is NOT active if:

- ❌ `SRGAN_ENABLE=0` in config
- ❌ Model file missing
- ❌ Logs only show FFmpeg output
- ❌ Only ffmpeg process, no python
- ❌ Low VRAM usage (< 1GB)
- ❌ Moderate GPU usage (30-50%)
- ❌ Fast processing (0.8-1.2x real-time)
- ❌ No mention of AI in logs

---

## 🚀 Quick Commands Reference

```bash
# Automated check
./scripts/check_ai_active.sh

# Check logs
docker logs srgan-upscaler | grep -i "ai\|model"

# Watch logs live
docker logs -f srgan-upscaler

# Check GPU
nvidia-smi

# Watch GPU live
watch -n 1 nvidia-smi

# Check config
docker compose exec srgan-upscaler printenv | grep SRGAN

# Check model file
docker compose exec srgan-upscaler ls -lh /app/models/
```

---

## 💡 Enable AI if Not Active

If verification shows AI is not active:

```bash
# 1. Download model if missing
./scripts/setup_model.sh

# 2. Enable in docker-compose.yml
nano docker-compose.yml
# Set: SRGAN_ENABLE=1

# 3. Restart container
docker compose restart srgan-upscaler

# 4. Verify again
./scripts/check_ai_active.sh
```

---

**Use the automated check script for the easiest verification!** ✨
