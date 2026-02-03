# Quick Start - AI Upscaling

## 🚀 One-Command Setup

```bash
git clone https://github.com/yourusername/Jellyfin-SRGAN-Plugin
cd Jellyfin-SRGAN-Plugin
sudo ./scripts/install_all.sh
```

**That's it!** The installer will:

1. ✅ Install dependencies (Docker, Python, PyTorch)
2. ✅ **Download SRGAN AI model** (~16MB, automatic)
3. ✅ Configure GPU acceleration
4. ✅ Enable denoising (removes artifacts)
5. ✅ Set up Jellyfin integration
6. ✅ Build and start containers

---

## ✨ What You Get

### AI-Powered Features

- 🧠 **Deep learning super-resolution** (not basic scaling)
- 🎨 **Texture reconstruction** (sharper details)
- 🧹 **Built-in denoising** (removes compression artifacts)
- ⚡ **GPU acceleration** (NVIDIA CUDA + NVENC)
- 🎬 **Real-time streaming** (HLS while processing)

### Default Settings

```yaml
SRGAN_ENABLE=1                    # AI model ON
SRGAN_SCALE_FACTOR=2.0            # 1080p → 4K
SRGAN_DENOISE=1                   # Denoising ON
SRGAN_DENOISE_STRENGTH=0.5        # Balanced
SRGAN_FP16=1                      # Fast mode (half-precision)
```

---

## 📊 What to Expect

### Quality

**Before (FFmpeg):**
- Smooth but soft edges
- Blurry textures
- No artifact removal
- Basic interpolation

**After (AI + Denoise):**
- ✅ Sharp edges and fine details
- ✅ Enhanced textures (fabric, skin, surfaces)
- ✅ Reduced compression blocks
- ✅ Cleaner gradients (no banding)

### Speed

| Source | Target | Time (2hr movie) | Quality Gain |
|--------|--------|------------------|--------------|
| 1080p | 4K | **8-16 hours** | ⭐⭐⭐⭐⭐ Excellent |
| 720p | 1080p | **6-10 hours** | ⭐⭐⭐⭐⭐ Huge |
| 480p | 1080p | **4-6 hours** | ⭐⭐⭐⭐⭐ Amazing |

**Note:** First-time processing. Subsequent plays use the cached upscaled version instantly.

---

## 🎯 Use Cases

### Perfect For

- ✅ Old movies (DVDs, VHS transfers)
- ✅ Anime and animation
- ✅ Low-bitrate streaming sources
- ✅ Classic TV shows
- ✅ Heavily compressed videos
- ✅ Upscaling to 4K displays

### Maybe Overkill For

- Modern 1080p+ Blu-rays (already excellent)
- Live TV (need real-time speed)
- Short-term watch once content
- Very large libraries (processing time)

---

## ⚙️ Quick Tuning

### Adjust Denoising

```bash
nano docker-compose.yml

# Find and edit:
- SRGAN_DENOISE_STRENGTH=0.5    # Default

# Options:
# 0.3 = Light (keep film grain)
# 0.5 = Balanced (recommended)
# 0.7 = Strong (very clean)

docker compose restart
```

### Switch to Fast Mode

If you need speed over quality:

```bash
nano docker-compose.yml

# Change:
- SRGAN_ENABLE=0    # Disable AI (use FFmpeg)

docker compose restart
```

Processes 3-10x faster but without AI enhancement.

---

## 🔍 Verify It's Working

### Check Status

```bash
./scripts/check_srgan_status.sh
```

**Should show:**

```
✅ SRGAN AI Model: READY

Status: AI-powered super-resolution enabled
Method: Deep learning neural network
Denoising: Enabled (strength: 0.5)
```

### Watch Processing

```bash
# Terminal 1: Watch logs
docker logs -f srgan-upscaler

# Terminal 2: Monitor GPU
watch -n 1 nvidia-smi

# Should see:
# - "AI Upscaling Configuration" in logs
# - 80-95% GPU usage
# - 3-8GB VRAM used
```

### Test a File

```bash
./scripts/test_upscaling.sh '/path/to/video.mp4'

# Will show:
# - AI model loading
# - Denoising status
# - Frame processing progress
# - HLS segment creation
```

---

## 🎬 First Run Workflow

1. **Play a video in Jellyfin**
   - AI upscaling starts automatically

2. **Monitor progress** (optional)
   ```bash
   docker logs -f srgan-upscaler
   ```

3. **Initial buffering** (~30-60 seconds)
   - First HLS segments being created

4. **Stream starts playing**
   - Watch upscaled video while rest processes

5. **Processing continues** in background
   - Takes several hours for full movie

6. **Next time**: Instant playback
   - Uses cached upscaled version

---

## 💡 Pro Tips

### Batch Process Your Library

Queue multiple files:

```bash
# Add jobs to queue
for file in /mnt/media/Movies/**/*.mp4; do
    echo "{\"input\":\"$file\",\"output\":\"./upscaled/$(basename "$file" .mp4).ts\",\"streaming\":true}" >> cache/queue.jsonl
done

# Container will process them one by one
```

### Overnight Processing

Perfect for setting up before bed:

```bash
# Queue your favorite movies
# Let it run overnight
# Wake up to upscaled content
```

### Check Queue Status

```bash
# See pending jobs
wc -l cache/queue.jsonl

# See what's currently processing
docker logs srgan-upscaler | tail -20
```

---

## 🐛 Common Issues

### Model Not Downloaded

```bash
# Download manually
./scripts/setup_model.sh

# Check if present
ls -lh models/swift_srgan_4x.pth
```

### GPU Not Detected

```bash
# Test GPU access
docker compose exec srgan-upscaler nvidia-smi

# If fails, install nvidia-container-toolkit:
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

### Processing Stuck

```bash
# Check logs for errors
docker logs srgan-upscaler | grep -i error

# Restart container
docker compose restart srgan-upscaler
```

### Out of Memory

```bash
# Edit docker-compose.yml
# Reduce scale factor:
- SRGAN_SCALE_FACTOR=1.5    # Instead of 2.0

# Or disable denoising temporarily:
- SRGAN_DENOISE=0

docker compose restart
```

---

## 📚 More Info

- **AI_UPSCALING_ENABLED.md** - Complete technical guide
- **SRGAN_MODEL_STATUS.md** - Detailed comparison
- **FFMPEG_NVENC_FIXED.md** - Hardware encoding setup

---

## 🎯 Bottom Line

**New default:**
- ✅ AI-powered upscaling (not basic scaling)
- ✅ Denoising enabled
- ✅ GPU accelerated
- ⏱️ Slower but **much better quality**

**To revert to fast mode:**
```bash
sed -i 's/SRGAN_ENABLE=1/SRGAN_ENABLE=0/' docker-compose.yml
docker compose restart
```

**Enjoy the AI magic!** 🎬✨
