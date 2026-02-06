# QUICK FIX - Input Not Encoding

## ✅ Issue: FIXED

Your input files weren't encoding because **`.ts` file filtering was too aggressive**.

## 🚀 Apply the Fix

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin

# Rebuild container with fix
docker compose down
docker compose build --no-cache
docker compose up -d

# Watch logs
docker logs -f srgan-upscaler
```

## ✅ What Was Fixed

**Before:** Rejected `.ts` files with "segment" or "hls" anywhere in path  
**After:** Only rejects actual HLS segment files (like `segment_000.ts`)

**Your legitimate `.ts` video files will now process!**

## 🔍 Verify It's Working

Play a video or add test job:
```bash
echo '{"input":"/path/to/video.ts","output":"/path/to/output.mkv"}' >> cache/queue.jsonl
docker logs -f srgan-upscaler
```

**Expected output:**
```
Using FFmpeg-based AI upscaling (recommended)
Loading AI model...
✓ Model loaded
Processed 30 frames...
```

## 📄 Details

See `INPUT_ENCODING_FIXED.md` for complete details.

---

**Files Changed:**
- ✅ `scripts/watchdog_api.py`
- ✅ `scripts/srgan_pipeline.py`

**No linter errors** - safe to rebuild!
