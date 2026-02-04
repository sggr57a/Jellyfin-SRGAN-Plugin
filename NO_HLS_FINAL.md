# HLS/TS Support COMPLETELY REMOVED

## 🚨 Critical: All HLS and TS Container Support Removed

HLS streaming and MPEGTS containers have been **completely removed** from the entire pipeline.

---

## ❌ What Was Removed

### 1. MPEGTS Container Support
```python
# REMOVED from your_model_file.py
output_container = "mpegts" if output_path.lower().endswith(".ts") else None
```

**Now:**
- Only `.mkv` and `.mp4` outputs supported
- Attempting `.ts` output raises an error immediately
- No MPEGTS container creation at all

---

### 2. HLS Streaming Functions
```python
# REMOVED: _run_ffmpeg_streaming() - entire function
# REMOVED: _finalize_hls_playlist() - entire function
```

**These functions now raise `NotImplementedError`:**
```
"HLS streaming mode has been removed. 
Only direct MKV/MP4 output is supported."
```

---

### 3. FFmpeg-Only Fallback Functions
```python
# REMOVED: _run_ffmpeg() - basic FFmpeg scaling
# REMOVED: _run_ffmpeg_direct() - FFmpeg direct output
```

**Both now raise `NotImplementedError`:**
```
"FFmpeg-only upscaling is no longer supported.
Use AI upscaling (SRGAN_ENABLE=1)."
```

---

## ✅ What's Supported Now

### Supported Output Formats

| Format | Extension | Container | Status |
|--------|-----------|-----------|--------|
| **Matroska** | `.mkv` | MKV | ✅ Supported (default) |
| **MPEG-4** | `.mp4` | MP4 | ✅ Supported |
| Transport Stream | `.ts` | MPEGTS | ❌ REMOVED |
| HLS Playlist | `.m3u8` | HLS | ❌ REMOVED |

---

### Supported Upscaling Methods

| Method | Status |
|--------|--------|
| **AI Upscaling (SRGAN)** | ✅ ONLY method |
| FFmpeg scaling | ❌ REMOVED |
| FFmpeg direct | ❌ REMOVED |
| HLS streaming | ❌ REMOVED |

---

## 🔧 Validation Added

### AI Model Validation

```python
# In your_model_file.py
output_ext = os.path.splitext(output_path)[1].lower()
if output_ext not in ['.mkv', '.mp4']:
    raise ValueError(f"Unsupported output format: {output_ext}")
```

**Result:** `.ts` outputs are rejected immediately at the AI model level.

---

### Input Validation (Already Present)

```python
# In watchdog_api.py and srgan_pipeline.py
if input_lower.endswith('.m3u8') or '/hls/' in input_lower:
    ERROR: "HLS stream inputs not supported"
```

**Result:** HLS inputs are rejected at both API and pipeline levels.

---

## 🧹 Cleanup Required

### Clear Old Job Queue

Old jobs in the queue might still reference `.ts` outputs or HLS directories.

**Run this command:**

```bash
# On the server
cd /root/Jellyfin-SRGAN-Plugin
./scripts/clear_queue.sh
```

**What it does:**
1. Backs up existing queue
2. Clears all pending jobs
3. New jobs will use MKV/MP4 only

---

### Remove Old HLS Output

If you have old HLS output directories:

```bash
# Find and remove HLS directories (BE CAREFUL!)
find /mnt/media -type d -name "hls" -exec rm -rf {} +

# Or manually:
rm -rf /root/Jellyfin-SRGAN-Plugin/upscaled/hls/
```

---

## 📋 Complete Pipeline Flow Now

```
1. User plays video in Jellyfin
   ↓
2. Webhook triggers → watchdog_api.py
   ↓
3. Validate input (reject if HLS)
   ↓
4. Determine output path:
   - Same directory as input
   - Format: MKV or MP4 (from OUTPUT_FORMAT env)
   - Temp filename: movie_upscaled.mkv
   ↓
5. Queue job:
   {
     "input": "/mnt/media/Movie [1080p].mkv",
     "output": "/mnt/media/Movie_upscaled.mkv",
     "streaming": False  ← Always False
   }
   ↓
6. Pipeline dequeues → srgan_pipeline.py
   ↓
7. Validate input again (reject if HLS)
   ↓
8. Check SRGAN_ENABLE=1 (must be enabled)
   ↓
9. Call _try_model() → your_model_file.py
   ↓
10. AI Model Process:
    - Get video info (resolution, HDR)
    - Generate intelligent filename
    - VALIDATE output format (.mkv or .mp4 ONLY)
    - Load SRGAN model
    - Apply denoising
    - Run AI inference on frames
    - Encode to MKV or MP4 (NO .ts!)
    ↓
11. Verify output:
    - File exists
    - Valid video
    - Correct resolution
    - Reasonable size
    ↓
12. Success!
    Output: /mnt/media/Movie [2160p] [HDR].mkv
```

**NO HLS. NO TS. NO FFMPEG FALLBACK.**

---

## 🚨 Error Messages You Might See

### If `.ts` Output Attempted

```
ValueError: Unsupported output format: .ts. 
Only .mkv and .mp4 are supported.
```

**Cause:** Old job in queue or bad configuration.

**Fix:** Clear queue and restart.

---

### If HLS Function Called

```
NotImplementedError: HLS streaming mode has been removed.
Only direct MKV/MP4 output is supported.
```

**Cause:** Old code path or deprecated function called.

**Fix:** Update to latest code.

---

### If FFmpeg Fallback Attempted

```
NotImplementedError: FFmpeg-only upscaling is no longer supported.
Use AI upscaling (SRGAN_ENABLE=1).
```

**Cause:** `SRGAN_ENABLE=0` or AI model failed.

**Fix:** Set `SRGAN_ENABLE=1` and ensure model file exists.

---

## 📊 Before vs After

### Before (With HLS/TS)

```python
# watchdog_api.py
if enable_streaming:
    hls_dir = ...
    job = {..., "hls_dir": hls_dir, "streaming": True}

# your_model_file.py  
output_container = "mpegts" if output_path.lower().endswith(".ts") else None

# srgan_pipeline.py
if not used_model:
    _run_ffmpeg_direct(...)  # FFmpeg fallback
```

**Problems:**
- Complex HLS logic
- TS container creation
- FFmpeg fallback (not AI)
- Confusing output

---

### After (Clean, MKV/MP4 Only)

```python
# watchdog_api.py
output_path = os.path.join(input_dir, f"{basename}_upscaled.{output_format}")
job = {"input": input_file, "output": output_path, "streaming": False}

# your_model_file.py
if output_ext not in ['.mkv', '.mp4']:
    raise ValueError(f"Unsupported: {output_ext}")

# srgan_pipeline.py
used_model = _try_model(...)
if not used_model:
    ERROR: "AI model failed!"  # NO FALLBACK
```

**Benefits:**
- ✅ Simple, direct output
- ✅ MKV/MP4 only
- ✅ AI mandatory
- ✅ Clear errors

---

## ✅ Verification

### Check No HLS References

```bash
# Should find ZERO results in active code
cd /root/Jellyfin-SRGAN-Plugin
grep -r "mpegts\|hls_dir\|\.ts\"" scripts/*.py | grep -v "REMOVED\|DEPRECATED"

# Should return nothing (or only comments)
```

---

### Check Output Format Validation

```bash
# Check AI model has validation
grep -A 3 "Unsupported output format" scripts/your_model_file.py

# Should show:
# if output_ext not in ['.mkv', '.mp4']:
#     raise ValueError(...)
```

---

### Test Upscaling

```bash
# 1. Clear queue
./scripts/clear_queue.sh

# 2. Restart containers
docker compose restart

# 3. Play video in Jellyfin

# 4. Check logs (should see .mkv output, NO .ts)
docker logs srgan-upscaler | grep "Output:"

# Should show:
# Output: /mnt/media/Movie [2160p].mkv  ← MKV, not TS!
```

---

## 🎯 Summary

**Removed:**
- ❌ MPEGTS container support (`.ts` files)
- ❌ HLS streaming mode (`.m3u8`, segments)
- ❌ FFmpeg-only upscaling (fallback)
- ❌ FFmpeg direct output (fallback)
- ❌ All deprecated functions

**Supported:**
- ✅ Matroska (`.mkv`) - default
- ✅ MPEG-4 (`.mp4`)
- ✅ AI upscaling ONLY (SRGAN)
- ✅ Direct file output
- ✅ Same directory as input

**Configuration:**
```yaml
# docker-compose.yml
environment:
  - OUTPUT_FORMAT=mkv  # or "mp4" - NO "ts"!
  - SRGAN_ENABLE=1     # Must be enabled
```

**Result:**
- Pure AI upscaling
- Clean MKV/MP4 output
- No HLS complexity
- Immediate errors if wrong format

**ALL HLS AND TS SUPPORT IS GONE. FOREVER.** 🎉
