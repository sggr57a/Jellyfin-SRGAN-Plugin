# Broken Pipe Error Fix

## ❌ Errors Fixed

### 1. NumPy Warning
```
UserWarning: The given NumPy array is not writable, and PyTorch does not support non-writable tensors.
```

### 2. Broken Pipe Error
```
BrokenPipeError: [Errno 32] Broken pipe
```

---

## ✅ Solutions Applied

### 1. NumPy Array Copy

**Problem:** `np.frombuffer()` returns read-only array.

**Fix:**
```python
# BEFORE
frame = np.frombuffer(frame_data, dtype=np.uint8).reshape(...)

# AFTER
frame = np.frombuffer(frame_data, dtype=np.uint8).reshape(...).copy()
                                                              ^^^^^^^^
                                                              Makes writable
```

**Result:** No more NumPy warnings, safe PyTorch conversion.

---

### 2. FFmpeg Process Monitoring

**Problem:** Output FFmpeg process dying silently.

**Fix:**
```python
# Check if encoder is still alive before each frame
if output_proc.poll() is not None:
    stderr_output = output_proc.stderr.read()
    raise RuntimeError(f"FFmpeg encoder died: {stderr_output}")
```

**Result:** Detect FFmpeg failures immediately with error details.

---

### 3. Stderr Capture

**Problem:** FFmpeg errors not visible.

**Fix:**
```python
# BEFORE
input_proc = subprocess.Popen(..., stderr=subprocess.DEVNULL)
output_proc = subprocess.Popen(..., stderr=subprocess.PIPE)

# AFTER
input_proc = subprocess.Popen(..., stderr=subprocess.PIPE)
output_proc = subprocess.Popen(..., stderr=subprocess.PIPE)
```

**Result:** Can see FFmpeg error messages for debugging.

---

### 4. Larger Pipe Buffer

**Problem:** Pipe buffer too small for high-res frames.

**Fix:**
```python
output_proc = subprocess.Popen(..., bufsize=10**8)
                                     ^^^^^^^^^^^^
                                     100MB buffer
```

**Result:** Less likely to block on large frames.

---

### 5. BrokenPipe Exception Handling

**Problem:** Broken pipe gives no context.

**Fix:**
```python
try:
    output_proc.stdin.write(upscaled.tobytes())
except BrokenPipeError:
    stderr_output = output_proc.stderr.read()
    raise RuntimeError(f"FFmpeg pipe broken: {stderr_output}")
```

**Result:** Know why FFmpeg died, not just that pipe broke.

---

### 6. Proper Cleanup

**Problem:** Processes not killed on errors.

**Fix:**
```python
except Exception as e:
    # Kill processes on error
    try:
        input_proc.kill()
    except:
        pass
    try:
        output_proc.kill()
    except:
        pass
    raise
```

**Result:** No zombie processes left running.

---

## 🚀 Deploy Fix

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Pull the fixes
git pull origin main

# Rebuild container
docker compose build srgan-upscaler

# Restart
docker compose restart srgan-upscaler
```

---

## 🔍 Error Messages You'll Now See

### Before (Cryptic)
```
BrokenPipeError: [Errno 32] Broken pipe
```

**No idea what went wrong!**

---

### After (Clear)
```
RuntimeError: FFmpeg encoder died unexpectedly:
[hevc_nvenc @ 0x...] OpenEncodeSessionEx failed: out of memory (10)
Error initializing output stream 0:0 -- Error while opening encoder
```

**Now you know: GPU out of memory!**

---

## 🎯 Common FFmpeg Errors Now Visible

### 1. GPU Out of Memory
```
[hevc_nvenc @ ...] OpenEncodeSessionEx failed: out of memory (10)
```

**Fix:** Lower resolution or use CPU encoder.

---

### 2. Codec Not Supported
```
Unknown encoder 'hevc_nvenc'
```

**Fix:** Check GPU drivers, use h264_nvenc or libx264.

---

### 3. Permission Denied
```
[matroska @ ...] Permission denied
```

**Fix:** Check output directory permissions.

---

### 4. Disk Full
```
[matroska @ ...] No space left on device
```

**Fix:** Free up disk space.

---

### 5. Invalid Parameters
```
[hevc_nvenc @ ...] Cannot load libcuda.so.1
```

**Fix:** NVIDIA drivers not installed or not accessible.

---

## 📊 Before vs After

### Before

| Issue | Status |
|-------|--------|
| NumPy warning | ❌ Every frame |
| Broken pipe | ❌ Cryptic error |
| FFmpeg errors | ❌ Hidden |
| Process cleanup | ❌ Incomplete |
| Debugging | ❌ Impossible |

### After

| Issue | Status |
|-------|--------|
| NumPy warning | ✅ Fixed |
| Broken pipe | ✅ Caught with context |
| FFmpeg errors | ✅ Visible |
| Process cleanup | ✅ Proper |
| Debugging | ✅ Easy |

---

## 🔍 Debugging Commands

### Check FFmpeg Encoder

```bash
# Test NVENC availability
docker exec srgan-upscaler ffmpeg -hide_banner -encoders | grep nvenc

# Should show:
# V..... hevc_nvenc
# V..... h264_nvenc
```

---

### Test Simple Encode

```bash
# Test if encoder works at all
docker exec srgan-upscaler ffmpeg -f lavfi -i testsrc=duration=1:size=1920x1080 \
    -c:v hevc_nvenc -f null -

# If this fails, GPU encoding is broken
```

---

### Check GPU Memory

```bash
# See GPU memory usage
nvidia-smi

# Or inside container
docker exec srgan-upscaler nvidia-smi
```

---

## 🎯 Summary

**Problems:**
1. ❌ NumPy warnings
2. ❌ Broken pipe with no context
3. ❌ FFmpeg errors hidden

**Solutions:**
1. ✅ Copy NumPy arrays
2. ✅ Monitor FFmpeg processes
3. ✅ Capture stderr
4. ✅ Larger pipe buffers
5. ✅ Better error handling
6. ✅ Proper cleanup

**Deploy:**
```bash
git pull origin main
docker compose build && docker compose restart srgan-upscaler
```

**Result:** Clear error messages, easy debugging! 🎉
