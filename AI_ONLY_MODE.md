# AI-Only Upscaling Mode

## 🚨 Critical Changes

The pipeline has been **completely refactored** to ensure **AI upscaling is always used** and **never falls back to FFmpeg-only scaling**.

---

## ✅ What Changed

### 1. AI Upscaling is Mandatory

**Before:**
```python
if enable_model:
    used_model = _try_model(...)
    
if not used_model:
    # Fallback to FFmpeg (no AI)
    _run_ffmpeg_direct(...)
```

**After:**
```python
# AI model MUST be enabled
if not enable_model:
    ERROR: "AI upscaling is disabled"
    continue

# Try AI model
used_model = _try_model(...)

if not used_model:
    ERROR: "AI model upscaling failed!"
    # Job is SKIPPED, no FFmpeg fallback
    continue
```

**Result:** If AI fails, the job fails. No silent fallback to basic scaling.

---

### 2. HLS Stream Inputs Rejected

**Added validation:**
```python
# Reject .m3u8, .m3u, and HLS paths
if input_lower.endswith('.m3u8') or '/hls/' in input_lower:
    ERROR: "HLS streams cannot be upscaled"
    return False

# Reject HLS segments
if input_lower.endswith('.ts') and 'hls' in input_lower:
    ERROR: "HLS segments cannot be upscaled"
    return False
```

**Supported inputs:**
- ✅ `.mkv`, `.mp4`, `.avi`, `.mov`, `.webm`
- ✅ Any raw video container format
- ❌ `.m3u8` (HLS playlists)
- ❌ HLS segments (`.ts` in HLS directories)
- ❌ Any path containing `/hls/`

---

### 3. HLS Streaming Mode Removed

**watchdog_api.py changes:**

**Before:**
```python
enable_streaming = os.environ.get("ENABLE_HLS_STREAMING", "1") == "1"

if enable_streaming:
    # Complex HLS streaming logic
    hls_dir = ...
    hls_playlist = ...
    job = {..., "hls_dir": hls_dir, "streaming": True}
```

**After:**
```python
# Always direct file output
output_path = os.path.join(output_dir, f"{basename}.{output_format}")

job = {
    "input": input_file,
    "output": output_path,
    "streaming": False  # Always False
}
```

**Result:** All output is direct MKV/MP4 files. No HLS complexity.

---

### 4. Intelligent Filename Generation in AI Path

**Added to `_try_model()`:**

```python
# Get video info (resolution, HDR)
video_info = _get_video_info(input_path)

# Calculate target resolution
target_height = int(video_info["height"] * scale_factor)

# Generate intelligent filename
intelligent_output_path = _generate_output_filename(
    input_path, 
    output_dir, 
    target_height, 
    is_hdr
)

# Use the intelligent path
upscale(
    input_path=input_path,
    output_path=intelligent_output_path,  # New filename!
    ...
)
```

**Result:** AI upscaling outputs get intelligent names like `Movie [2160p] [HDR].mkv`

---

## 🎯 Pipeline Flow Now

```
1. Jellyfin playback starts
   ↓
2. Webhook triggers watchdog API
   ↓
3. API queries Jellyfin /Sessions
   ↓
4. Extract file path from NowPlayingItem
   ↓
5. VALIDATE: Reject if HLS stream
   ↓
6. Queue job with direct output path
   ↓
7. Pipeline dequeues job
   ↓
8. VALIDATE: Reject if HLS stream
   ↓
9. CHECK: Is SRGAN_ENABLE=1?
   ├─ NO  → ERROR: "AI must be enabled"
   └─ YES → Continue
   ↓
10. Run AI upscaling (_try_model)
    ├─ Get video info (resolution, HDR)
    ├─ Generate intelligent filename
    ├─ Load SRGAN model
    ├─ Apply denoising (if enabled)
    ├─ Run AI inference on each frame
    └─ Encode to MKV/MP4
   ↓
11. SUCCESS?
    ├─ YES → ✓ Output: Movie [2160p] [HDR].mkv
    └─ NO  → ✗ ERROR logged, job skipped
```

**NO FALLBACK TO FFMPEG!**

---

## 🔍 How to Verify AI is Being Used

### 1. Check Logs for AI Indicators

```bash
docker logs srgan-upscaler | grep -A 10 "AI Upscaling"
```

**Should show:**
```
AI Upscaling Configuration:
  Model: /app/models/swift_srgan_4x.pth
  Device: cuda
  FP16: True
  Scale: 4x
  Denoising: Enabled
  Denoise Strength: 0.5
```

### 2. Check for Model Loading

```bash
docker logs srgan-upscaler | grep "Model:"
```

**Should show:**
```
  Model: /app/models/swift_srgan_4x.pth
```

### 3. Check GPU Usage During Processing

```bash
watch -n 1 nvidia-smi
```

**Should show:**
```
| NVIDIA-SMI 555.42.06              Driver Version: 555.42.06    CUDA Version: 12.5     |
|-------------------------------+----------------------+----------------------+
|   0  NVIDIA GeForce RTX 4090  | Python    100%   15GB / 24GB |   95W / 450W |
```

**Key indicators:**
- Python process using GPU
- High GPU utilization (>80%)
- VRAM usage (several GB)
- Power draw increase

### 4. Check Processing Speed

**AI upscaling:**
- Takes 2-10x real-time (depending on GPU)
- Uses significant VRAM (4-12GB)
- GPU temperature increases

**FFmpeg-only scaling:**
- Runs at near real-time
- Uses minimal VRAM (<500MB)
- Low GPU utilization

If upscaling is fast (<2x real-time), it's NOT using AI!

---

## 🚨 Common Errors and Solutions

### Error: "AI upscaling is disabled"

```
ERROR: AI upscaling is disabled (SRGAN_ENABLE=0)
AI upscaling must be enabled. Set SRGAN_ENABLE=1
```

**Solution:**
```yaml
# docker-compose.yml
environment:
  - SRGAN_ENABLE=1  # Must be 1
```

Then:
```bash
docker compose down && docker compose up -d
```

---

### Error: "AI model upscaling failed!"

```
ERROR: AI model upscaling failed!
Possible reasons:
  1. Model file not found (check SRGAN_MODEL_PATH)
  2. Model file is corrupted
  3. GPU memory exhausted
  4. CUDA/PyTorch error
```

**Debug:**

1. Check model file exists:
```bash
docker exec srgan-upscaler ls -lh /app/models/
# Should show: swift_srgan_4x.pth (15-20MB)
```

2. Check GPU is accessible:
```bash
docker exec srgan-upscaler nvidia-smi
# Should show GPU info, not errors
```

3. Check VRAM available:
```bash
nvidia-smi
# Should show >4GB free VRAM
```

4. Check detailed logs:
```bash
docker logs srgan-upscaler 2>&1 | tail -100
```

---

### Error: "HLS streams cannot be upscaled"

```
ERROR: HLS stream inputs are not supported
Only raw video files (MKV, MP4, AVI, etc.) can be upscaled
```

**Cause:** Jellyfin is transcoding to HLS before the webhook triggers.

**Solution:** Ensure Direct Play is enabled in Jellyfin:
1. Jellyfin Dashboard → Playback
2. Enable: **Allow video playback that requires conversion without re-encoding**
3. Client settings → Playback → **Prefer Direct Play**

This ensures the original file is played, not an HLS stream.

---

## 📊 Performance Expectations

### AI Upscaling (Current Mode)

| Input | GPU | Speed | VRAM | Quality |
|-------|-----|-------|------|---------|
| 720p  | RTX 4090 | 3x realtime | 6GB | Excellent |
| 1080p | RTX 4090 | 2x realtime | 8GB | Excellent |
| 1080p | RTX 3080 | 1.5x realtime | 6GB | Excellent |
| 720p  | RTX 3060 | 1.2x realtime | 4GB | Excellent |

**Quality improvement:** 
- Sharper edges
- Better texture detail
- Reduced compression artifacts
- Enhanced fine details

---

### FFmpeg-Only Scaling (NOT USED)

| Input | Speed | VRAM | Quality |
|-------|-------|------|---------|
| Any   | 1x realtime | <500MB | Poor |

**Quality:** Basic Lanczos scaling (like any video player)
- Blurry
- No detail enhancement
- Just resizes pixels

**This mode is NO LONGER AVAILABLE in normal operation.**

---

## 🔧 Configuration

### Required Environment Variables

```yaml
# docker-compose.yml
environment:
  # CRITICAL: Must be 1 for AI upscaling
  - SRGAN_ENABLE=1
  
  # Model configuration
  - SRGAN_MODEL_PATH=/app/models/swift_srgan_4x.pth
  - SRGAN_DEVICE=cuda
  - SRGAN_FP16=1
  - SRGAN_SCALE_FACTOR=2.0
  
  # Denoising
  - SRGAN_DENOISE=1
  - SRGAN_DENOISE_STRENGTH=0.5
  
  # Output
  - OUTPUT_FORMAT=mkv
  - UPSCALED_DIR=/data/upscaled
```

---

## ✅ Verification Checklist

After updating, verify:

- [ ] `SRGAN_ENABLE=1` in docker-compose.yml
- [ ] Model file exists: `docker exec srgan-upscaler ls -lh /app/models/swift_srgan_4x.pth`
- [ ] GPU accessible: `docker exec srgan-upscaler nvidia-smi`
- [ ] Container rebuilt: `docker compose build && docker compose up -d`
- [ ] Test playback triggers upscaling
- [ ] Logs show "AI Upscaling Configuration"
- [ ] GPU usage spikes during processing
- [ ] Output has intelligent filename (e.g., `Movie [2160p] [HDR].mkv`)

---

## 🎯 Summary

**What This Means:**

✅ Every file is upscaled with AI (SRGAN model)  
✅ No silent fallback to basic FFmpeg scaling  
✅ HLS streams are rejected (only raw files accepted)  
✅ Output filenames include resolution and HDR tags  
✅ Failures are logged clearly with debug info  
✅ Denoising is applied before AI inference  

**If AI upscaling fails, the job fails. Period.**

This ensures you always get **true AI-enhanced quality**, never basic scaling masquerading as AI upscaling.

---

## 🚀 Deployment

Pull changes and rebuild:

```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
docker compose build srgan-upscaler
docker compose down && docker compose up -d

# Verify AI is active
docker logs srgan-upscaler | grep "AI Upscaling Configuration"
```

Done! 🎉
