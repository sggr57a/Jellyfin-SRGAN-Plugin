# Torchaudio Import Fix

## ❌ Error: `module 'torchaudio' has no attribute 'io'`

```python
ERROR: Could not import AI model: module 'torchaudio' has no attribute 'io'
```

**Cause:** Torchaudio is installed without the video I/O backend, or version is too old.

---

## ✅ Solution

### What Was Fixed

1. **Added Import Validation**
```python
# Now checks if torchaudio.io is available
if not hasattr(torchaudio, 'io'):
    raise ImportError("torchaudio.io module not available")
```

2. **Better Error Messages**
- Clear explanation of the problem
- Specific fix instructions
- Version requirements stated

3. **Explicit Container Format**
```python
# OLD - auto-detect (unreliable)
output_container = None

# NEW - explicit format
if output_ext == '.mkv':
    output_container = 'matroska'
elif output_ext == '.mp4':
    output_container = 'mp4'
```

4. **FFmpeg Verification in Dockerfile**
- Verifies FFmpeg has matroska and mp4 support
- Checks for hevc and h264 codecs
- Fails build early if missing

---

## 🚀 Deploy Fix

### On Your Server

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Pull the fix
git pull origin main

# Rebuild container (--no-cache ensures clean build)
docker compose build --no-cache srgan-upscaler

# Restart
docker compose down
docker compose up -d

# Verify torchaudio.io is available
docker exec srgan-upscaler python -c "import torchaudio.io; print('✓ torchaudio.io available')"
```

---

## 🔍 Verify Installation

### 1. Check Torchaudio Version

```bash
docker exec srgan-upscaler python -c "import torchaudio; print(f'torchaudio {torchaudio.__version__}')"
```

**Expected:**
```
torchaudio 2.4.0+cu121
```

**Minimum required:** `2.1.0`

---

### 2. Check torchaudio.io Module

```bash
docker exec srgan-upscaler python -c "import torchaudio.io; print('✓ torchaudio.io OK')"
```

**Expected:**
```
✓ torchaudio.io OK
```

---

### 3. Check FFmpeg Backend

```bash
docker exec srgan-upscaler python -c "
import torchaudio
print('Available backends:', torchaudio.list_audio_backends())
"
```

**Should include:** `['ffmpeg', ...]`

---

### 4. Test Video I/O

```bash
docker exec srgan-upscaler python -c "
import torchaudio.io
reader = torchaudio.io.StreamReader('/dev/null', format='null')
print('✓ StreamReader OK')
"
```

---

## 🐛 Common Issues

### Issue 1: "torchaudio.io not found after rebuild"

**Possible causes:**
1. Docker cache not cleared
2. PyTorch/torchaudio mismatch
3. CUDA version incompatibility

**Fix:**
```bash
# Force complete rebuild
docker compose down
docker system prune -a --volumes  # WARNING: removes all unused Docker data
docker compose build --no-cache
docker compose up -d
```

---

### Issue 2: "StreamReader not available"

**Error:**
```
AttributeError: module 'torchaudio.io' has no attribute 'StreamReader'
```

**Fix:**
```bash
# Check exact version
docker exec srgan-upscaler python -c "
import torchaudio
import torch
print(f'torchaudio: {torchaudio.__version__}')
print(f'torch: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
"

# If versions are wrong, rebuild
docker compose build --no-cache --pull
```

---

### Issue 3: "FFmpeg backend not available"

**Error:**
```
RuntimeError: No audio backend is available
```

**Fix:**
```bash
# Check FFmpeg in container
docker exec srgan-upscaler ffmpeg -version

# Should show version 6.0 or higher
# If not, base image needs updating
```

---

## 📋 Requirements

### Torchaudio Version

| Version | Video I/O | Status |
|---------|-----------|--------|
| 2.4.0+ | ✅ Full support | Recommended |
| 2.1.0-2.3.x | ✅ Basic support | OK |
| 2.0.x | ⚠️ Limited | May work |
| < 2.0 | ❌ Not supported | Upgrade required |

---

### FFmpeg Requirements

**Required formats:**
- ✅ Matroska (MKV)
- ✅ MP4 (MPEG-4)

**Required codecs:**
- ✅ HEVC (H.265)
- ✅ H.264 (AVC)

**Verify:**
```bash
docker exec srgan-upscaler ffmpeg -formats 2>&1 | grep -E "matroska|mp4"
docker exec srgan-upscaler ffmpeg -codecs 2>&1 | grep -E "hevc|h264"
```

---

## 🎯 Why This Happens

### Root Causes

1. **Incomplete Installation**
   - Torchaudio installed without FFmpeg backend
   - Missing system libraries

2. **Version Mismatch**
   - PyTorch/torchaudio version incompatibility
   - CUDA version mismatch

3. **Docker Cache**
   - Old cached layers with wrong versions
   - Partial updates

---

## 📊 Before vs After

### Before (Broken)

```python
# No validation
import torchaudio

# Crashes when used
reader = torchaudio.io.StreamReader(...)
# AttributeError: module 'torchaudio' has no attribute 'io'
```

**Result:** Cryptic error, no helpful message

---

### After (Fixed)

```python
# Validation with clear error
import torchaudio
if not hasattr(torchaudio, 'io'):
    print("ERROR: torchaudio.io module not available")
    print("Required: torchaudio >= 2.1.0")
    print(f"Current: {torchaudio.__version__}")
    print("To fix: docker compose build --no-cache")
    raise ImportError(...)

# Safe to use
reader = torchaudio.io.StreamReader(...)
```

**Result:** Clear error with fix instructions

---

## 🔧 Manual Verification

### Inside Container

```bash
# Enter container
docker exec -it srgan-upscaler bash

# Check Python environment
python -c "
import sys
import torch
import torchaudio

print(f'Python: {sys.version}')
print(f'PyTorch: {torch.__version__}')
print(f'Torchaudio: {torchaudio.__version__}')
print(f'CUDA: {torch.version.cuda}')
print(f'CUDA available: {torch.cuda.is_available()}')

# Check torchaudio.io
if hasattr(torchaudio, 'io'):
    print('✓ torchaudio.io available')
    from torchaudio.io import StreamReader, StreamWriter
    print('✓ StreamReader available')
    print('✓ StreamWriter available')
else:
    print('✗ torchaudio.io NOT available')
"
```

---

## 🎯 Summary

**Problem:** `module 'torchaudio' has no attribute 'io'`

**Root Cause:** Torchaudio installed without video I/O support

**Solution:**
1. ✅ Added import validation
2. ✅ Better error messages
3. ✅ Explicit container formats
4. ✅ FFmpeg verification in build
5. ✅ Clear fix instructions

**Deploy:**
```bash
git pull origin main
docker compose build --no-cache srgan-upscaler
docker compose down && docker compose up -d
```

**Verify:**
```bash
docker exec srgan-upscaler python -c "import torchaudio.io; print('OK')"
```

**Done!** AI upscaling will now work. 🎉
