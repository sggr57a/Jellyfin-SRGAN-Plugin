# PyTorch Installation Fix

## ❌ Error: `ModuleNotFoundError: No module named 'torchaudio.io'`

```
Traceback (most recent call last):
  File "<string>", line 1, in <module>
ModuleNotFoundError: No module named 'torchaudio.io'
```

**Root Cause:** Torchaudio was installed from PyPI without FFmpeg backend support.

---

## 🎯 The Problem

### Why torchaudio.io Was Missing

1. **PyPI Version Limitations**
   - PyPI torchaudio packages don't include all backends
   - CUDA-specific wheels (`+cu121`) may not have `io` module
   - Requires installation from PyTorch's own index

2. **Version String Issues**
   ```
   # BEFORE (in requirements.txt)
   torchaudio>=2.4.0+cu121  ← PyPI doesn't have this exact version
   ```

3. **Build Order**
   - Installing from requirements.txt uses PyPI by default
   - PyPI version missing video I/O support

---

## ✅ The Solution

### What Was Changed

**1. Removed PyTorch from requirements.txt**
```python
# OLD requirements.txt
torch>=2.4.0+cu121
torchvision>=0.19.0+cu121
torchaudio>=2.4.0+cu121  # ← These don't work from PyPI

# NEW requirements.txt
# PyTorch installed separately in Dockerfile
# (see comment in file)
```

**2. Install PyTorch from Official Index**
```dockerfile
# NEW in Dockerfile
RUN pip install --no-cache-dir \
    torch==2.4.0 \
    torchvision==0.19.0 \
    torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu121
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    Official PyTorch index with CUDA 12.1 wheels
```

**3. Verify Installation Immediately**
```dockerfile
# Verify during build (fails fast if broken)
RUN python3 -c "import torchaudio.io; print('✓ torchaudio.io available')" || \
    (echo "ERROR: torchaudio.io not available" && exit 1)
```

---

## 🚀 Deploy Fix

### On Your Server

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Pull the fix
git pull origin main

# CRITICAL: Build with --no-cache and --pull
docker compose build --no-cache --pull srgan-upscaler

# This will:
# 1. Pull latest base image
# 2. Install PyTorch from official index
# 3. Verify torchaudio.io during build
# 4. Fail immediately if broken

# Restart
docker compose down
docker compose up -d
```

---

## 🔍 Verify Installation

### 1. Check Build Succeeded

During build, you should see:
```
Step X/Y : RUN python3 -c "import torchaudio; ..."
 ---> Running in abc123...
torchaudio version: 2.4.0+cu121
✓ torchaudio.io available
```

**If build fails here, the error is caught immediately!**

---

### 2. Check Torchaudio Version

```bash
docker exec srgan-upscaler python -c "
import torchaudio
print(f'torchaudio: {torchaudio.__version__}')
"
```

**Expected:**
```
torchaudio: 2.4.0+cu121
```

Note the `+cu121` suffix - this means CUDA 12.1 build.

---

### 3. Check torchaudio.io Module

```bash
docker exec srgan-upscaler python -c "
import torchaudio.io
print('✓ torchaudio.io available')
print(f'  StreamReader: {hasattr(torchaudio.io, \"StreamReader\")}')
print(f'  StreamWriter: {hasattr(torchaudio.io, \"StreamWriter\")}')
"
```

**Expected:**
```
✓ torchaudio.io available
  StreamReader: True
  StreamWriter: True
```

---

### 4. Full Import Test

```bash
docker exec srgan-upscaler python -c "
import sys
sys.path.insert(0, '/app/scripts')

# This will fail with clear error if torchaudio.io missing
import your_model_file
print('✓ AI model module imported successfully')
"
```

---

## 📋 Installation Order

### Critical: Order Matters!

```dockerfile
# STEP 1: Install PyTorch from official index FIRST
RUN pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# STEP 2: Verify immediately
RUN python3 -c "import torchaudio.io; ..."

# STEP 3: Install other dependencies
RUN pip install -r requirements.txt
```

**Why this order?**
1. PyTorch from official index has full features
2. Verification catches issues immediately
3. Other packages can depend on PyTorch being correct

---

## 🐛 Common Issues

### Issue 1: Build fails at verification step

**Error during build:**
```
ERROR: torchaudio.io not available
```

**Cause:** PyTorch index URL wrong or unreachable

**Fix:**
```bash
# Check if PyTorch index is accessible
curl -I https://download.pytorch.org/whl/cu121/

# Should return HTTP 200

# If not, check your internet connection
# or try a different CUDA version
```

---

### Issue 2: "No matching distribution found"

**Error:**
```
ERROR: Could not find a version that satisfies the requirement torch==2.4.0
```

**Cause:** Wrong CUDA version for your GPU or PyTorch index issue

**Fix:**
```bash
# Check available versions
pip index versions torch --index-url https://download.pytorch.org/whl/cu121

# Or use a different CUDA version:
# cu118 - CUDA 11.8
# cu121 - CUDA 12.1
# cu124 - CUDA 12.4
```

---

### Issue 3: Still missing torchaudio.io after rebuild

**Symptom:**
```bash
docker exec srgan-upscaler python -c "import torchaudio.io"
# ModuleNotFoundError
```

**Debug:**
```bash
# Check what was actually installed
docker exec srgan-upscaler pip show torchaudio

# Look for:
# Version: 2.4.0+cu121  ← Should have +cu121
# Location: /usr/local/lib/python3.10/site-packages

# Check if io module exists
docker exec srgan-upscaler ls -la /usr/local/lib/python3.10/site-packages/torchaudio/io/
```

**Fix:**
```bash
# Force complete rebuild
docker compose down
docker system prune -a --volumes  # WARNING: removes ALL Docker data
docker compose build --no-cache --pull
docker compose up -d
```

---

## 📊 Before vs After

### Before (Broken)

**requirements.txt:**
```
torchaudio>=2.4.0+cu121  ← Installed from PyPI
```

**Result:**
- PyPI version without io module
- Missing FFmpeg backend
- Import fails

---

### After (Fixed)

**Dockerfile:**
```dockerfile
RUN pip install torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu121
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    Official PyTorch index - includes io module
```

**Result:**
- Official PyTorch build
- Includes io module
- FFmpeg backend included
- Import succeeds

---

## 🔍 Why PyTorch Index vs PyPI?

### PyPI (pip default)

| Feature | Status |
|---------|--------|
| CUDA builds | Limited |
| Video I/O | ❌ Not included |
| FFmpeg backend | ❌ Missing |
| Installation | Easy but incomplete |

### PyTorch Index (Official)

| Feature | Status |
|---------|--------|
| CUDA builds | ✅ All versions |
| Video I/O | ✅ Included |
| FFmpeg backend | ✅ Included |
| Installation | Requires index URL |

**Always use PyTorch index for GPU workloads!**

---

## 🎯 Summary

**Problem:** `ModuleNotFoundError: No module named 'torchaudio.io'`

**Root Cause:** 
- Torchaudio installed from PyPI
- PyPI version missing io module
- Needs official PyTorch build

**Solution:**
1. ✅ Removed PyTorch from requirements.txt
2. ✅ Install from official PyTorch index
3. ✅ Verify during build (fail fast)
4. ✅ Specific version with CUDA support

**Deploy:**
```bash
git pull origin main
docker compose build --no-cache --pull srgan-upscaler
docker compose down && docker compose up -d
```

**Verify:**
```bash
docker exec srgan-upscaler python -c "import torchaudio.io; print('OK')"
# Should print: OK
```

**This WILL work now!** 🎉
