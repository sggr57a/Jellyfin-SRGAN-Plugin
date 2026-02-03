# NVIDIA Patch Fixed - Now Runs at Container Start

## ❌ Previous Error

```
Failed to initialize NVML: Unknown Error
nvidia-smi retcode: 255
```

**During Docker build** when trying to run NVIDIA patch script.

## 🔍 Root Cause

**GPU is NOT accessible during Docker image build** - only at runtime.

The NVIDIA patch script runs `nvidia-smi` to detect the driver version, but:
- ❌ Build time: No GPU access → `nvidia-smi` fails
- ✅ Runtime: GPU accessible → `nvidia-smi` works

## ✅ Solution

Move NVIDIA patch execution from **build time** to **container start time**.

---

## 🔧 What Changed

### Before (Broken)

**Dockerfile:**
```dockerfile
# This runs during BUILD (no GPU access)
RUN git clone https://github.com/sggr57a/nvidia-patch.git && \
    cd nvidia-patch && \
    bash ./patch.sh  # ❌ FAILS - no GPU during build
```

### After (Fixed)

**Dockerfile:**
```dockerfile
# Clone during build (no execution)
RUN git clone https://github.com/sggr57a/nvidia-patch.git /opt/nvidia-patch

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use entrypoint that runs patch at startup
ENTRYPOINT ["/entrypoint.sh"]
```

**entrypoint.sh:**
```bash
#!/bin/bash
# This runs at CONTAINER START (GPU accessible)

if nvidia-smi >/dev/null 2>&1; then
    echo "GPU detected, applying NVIDIA patch..."
    cd /opt/nvidia-patch
    bash ./patch.sh  # ✅ WORKS - GPU available at runtime
fi

# Start main application
exec python /app/scripts/srgan_pipeline.py "$@"
```

---

## 🎯 What the Patch Does

The NVIDIA driver patch removes the artificial limit on:
- **Number of simultaneous NVENC encoding sessions**
- **Number of simultaneous NVDEC decoding sessions**

**Default limits:**
- Consumer GPUs (GeForce): 2-3 simultaneous sessions
- Professional GPUs (Quadro/Tesla): Unlimited

**After patch:**
- All GPUs: Unlimited sessions

This allows processing multiple videos simultaneously.

---

## 🚀 Deploy the Fix

On your server:

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Pull fixed Dockerfile and entrypoint
git pull origin main

# Rebuild container (will now succeed)
docker compose build --no-cache srgan-upscaler

# Start container
docker compose up -d

# Check logs (should see patch applied)
docker logs srgan-upscaler
```

---

## ✅ Expected Behavior

### During Build (No Errors)

```
[+] Building 45.3s (18/18) FINISHED
 => [13/13] RUN git clone https://github.com/sggr57a/nvidia-patch.git
 => [14/14] COPY entrypoint.sh /entrypoint.sh
 => exporting to image
✓ Container built successfully
```

### At Container Start (Patch Applied)

```bash
docker logs srgan-upscaler

# Output:
GPU detected, checking NVIDIA driver patch status...
✓ NVIDIA driver patch applied/verified

Starting SRGAN pipeline...
Using streaming mode (HLS)
...
```

---

## 🔍 Verification

### Check if Patch Was Applied

```bash
# See container startup logs
docker logs srgan-upscaler 2>&1 | head -20

# Should show one of:
# "✓ NVIDIA driver patch applied/verified"
# "✓ NVIDIA driver already patched"
# "GPU not accessible" (if no GPU passed to container)
```

### Test Simultaneous Encoding

Before patch:
```bash
# Start 3 encodings simultaneously
# Result: 3rd one fails with "No more encoding sessions available"
```

After patch:
```bash
# Start 10+ encodings simultaneously
# Result: All work (limited only by GPU memory/power)
```

---

## 🛡️ Safety Features

The entrypoint script is designed to be safe:

1. **Checks GPU availability** before patching
2. **Skips if already patched** (idempotent)
3. **Continues if patch fails** (doesn't block pipeline)
4. **Works without GPU** (for testing/development)

```bash
# If GPU not available:
"GPU not accessible in container, skipping NVIDIA patch"
→ Pipeline starts normally

# If already patched:
"✓ NVIDIA driver already patched"
→ Pipeline starts normally

# If patch fails:
"⚠ NVIDIA patch skipped"
→ Pipeline starts normally (just with session limits)
```

---

## 🎬 Container Startup Flow

```
1. Container starts
2. entrypoint.sh runs
3. ├─ Check if nvidia-smi exists
4. ├─ Check if GPU is accessible
5. ├─ Apply NVIDIA patch (if needed)
6. └─ Start SRGAN pipeline
```

The pipeline always starts, even if patching fails.

---

## 🔧 Manual Patch Application

If you need to manually check/apply the patch:

```bash
# Enter running container
docker compose exec srgan-upscaler bash

# Check if patch is applied
cd /opt/nvidia-patch
bash ./patch.sh

# Output will show:
# - "Patched!" if successfully applied
# - "Already patched" if already done
# - Error if driver not supported
```

---

## 📊 Comparison

| Aspect | Build Time (Old) | Runtime (New) |
|--------|------------------|---------------|
| **GPU Access** | ❌ No | ✅ Yes |
| **nvidia-smi** | ❌ Fails | ✅ Works |
| **Patch Application** | ❌ Impossible | ✅ Successful |
| **Build Success** | ❌ Fails | ✅ Succeeds |
| **Flexibility** | ❌ Fixed at build | ✅ Adapts to runtime GPU |

---

## 🐛 Troubleshooting

### Patch Not Applied

Check container logs:
```bash
docker logs srgan-upscaler 2>&1 | grep -i "nvidia\|patch"
```

Possible reasons:
- GPU not passed to container (check `docker-compose.yml`)
- Driver not supported by patch
- Already patched by system

### Still Hit Session Limit

```bash
# Check if patch was successful
docker compose exec srgan-upscaler bash
nvidia-smi
# Should show GPU info

cd /opt/nvidia-patch
bash ./patch.sh
# Check output for success/failure
```

### Verify Session Limit Removed

```bash
# Before: nvidia-smi shows error after 2-3 sessions
# After: Should handle many simultaneous sessions

# Test by starting multiple encodes
for i in {1..5}; do
  docker compose exec srgan-upscaler ffmpeg -i input.mp4 -c:v hevc_nvenc output_$i.mp4 &
done

# All should succeed (no session limit errors)
```

---

## 📚 Related Documentation

- **Dockerfile** - Container build configuration
- **entrypoint.sh** - Runtime startup script
- **docker-compose.yml** - Service configuration with GPU access

---

## 🎯 Summary

**Problem:** NVIDIA patch fails during Docker build (no GPU access)  
**Solution:** Run patch at container start (GPU available)  
**Result:** Build succeeds, patch applied at runtime automatically  

**Deploy fix:**
```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main
docker compose build --no-cache srgan-upscaler
docker compose up -d
```

**No more build failures!** 🚀
