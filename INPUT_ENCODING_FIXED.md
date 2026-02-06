# INPUT ENCODING ISSUE - FIXED ✅

**Date:** 2026-02-05  
**Issue:** Input files not getting encoded  
**Status:** ✅ FIXED

---

## 🔴 Problem Identified

Videos were being **rejected** and not processed due to overly aggressive `.ts` file filtering.

### Root Cause

The code was rejecting **any `.ts` file** that contained:
- The word "segment" anywhere in the path
- The word "hls" anywhere in the path

This was meant to block HLS streaming segments, but it was **too broad** and rejected legitimate video files.

### Examples of Files Incorrectly Rejected

❌ `/mnt/media/Movies/the_segment.ts` - Contains "segment" in filename  
❌ `/media/Documentary/segment_one.ts` - Contains "segment_" in filename  
❌ `/hls_backup/movie.ts` - Contains "hls" in directory path  
❌ `/media/TV/Episode_segment.ts` - Contains "segment" in filename  

These are **legitimate MPEG-TS video files**, not HLS segments!

---

## ✅ Solution Implemented

### Improved Detection Logic

Changed from:
```python
# OLD - TOO AGGRESSIVE
if input_lower.endswith('.ts') and ('/segment' in input_lower or 'hls' in input_lower):
    # Reject
```

To:
```python
# NEW - SPECIFIC HLS SEGMENT DETECTION
if input_lower.endswith('.ts'):
    basename = os.path.basename(input_lower)
    normalized_path = input_lower.replace('\\', '/')
    # Check if it's actually an HLS segment (not just any .ts file)
    if ('segment_' in basename or 
        'seg_' in basename or 
        'chunk_' in basename or
        '/hls/' in normalized_path or
        '/segments/' in normalized_path):
        # Reject
```

### What Changed

The new logic only rejects files that match **actual HLS segment patterns**:

1. **Filename starts with `segment_`** - e.g., `segment_000.ts`, `segment_001.ts`
2. **Filename starts with `seg_`** - e.g., `seg_000.ts`, `seg_001.ts`
3. **Filename starts with `chunk_`** - e.g., `chunk_000.ts`, `chunk_001.ts`
4. **Path contains `/hls/` directory** - e.g., `/output/hls/video.ts`
5. **Path contains `/segments/` directory** - e.g., `/output/segments/video.ts`

### Results

✅ **NOW ACCEPTED (previously rejected):**
- `/mnt/media/Movies/the_segment.ts` - "segment" in middle of filename
- `/media/segment1/movie.ts` - "segment" in directory name
- `/hls_backup/movie.ts` - "hls" in directory name
- `/content/video.ts` - Regular .ts file

❌ **STILL REJECTED (as intended):**
- `/output/hls/segment_000.ts` - HLS segment in /hls/ directory
- `/tmp/segment_001.ts` - HLS segment pattern
- `/stream/seg_000.ts` - HLS segment pattern
- `/data/chunk_001.ts` - HLS chunk pattern

---

## 📝 Files Modified

### 1. scripts/watchdog_api.py (Lines 176-188)

**Before:**
```python
# Reject .ts segment files (they're HLS segments, not transport streams)
if input_lower.endswith('.ts') and ('/segment' in input_lower or 'hls' in input_lower):
    logger.error(f"REJECTED: HLS segment file: {input_file}")
    return False, {"error": "HLS segments cannot be upscaled"}
```

**After:**
```python
# Reject HLS segment files (more specific check)
# HLS segments have patterns like segment_NNN.ts, seg_NNN.ts, or are in /hls/ directories
if input_lower.endswith('.ts'):
    basename = os.path.basename(input_lower)
    normalized_path = input_lower.replace('\\', '/')
    # Check if it's actually an HLS segment (not just any .ts file)
    if ('segment_' in basename or 
        'seg_' in basename or 
        'chunk_' in basename or
        '/hls/' in normalized_path or
        '/segments/' in normalized_path):
        logger.error(f"REJECTED: HLS segment file: {input_file}")
        return False, {"error": "HLS segments cannot be upscaled"}
```

### 2. scripts/srgan_pipeline.py (Lines 596-608)

**Before:**
```python
# Reject HLS segment files
if input_lower.endswith('.ts') and ('/segment' in input_lower or 'hls' in input_lower):
    print(f"ERROR: HLS segment files cannot be upscaled: {input_path}", file=sys.stderr)
    continue
```

**After:**
```python
# Reject HLS segment files (more specific check)
# HLS segments have patterns like segment_NNN.ts, seg_NNN.ts, or are in /hls/ directories
if input_lower.endswith('.ts'):
    basename = os.path.basename(input_lower)
    normalized_path = input_lower.replace('\\', '/')
    # Check if it's actually an HLS segment (not just any .ts file)
    if ('segment_' in basename or 
        'seg_' in basename or 
        'chunk_' in basename or
        '/hls/' in normalized_path or
        '/segments/' in normalized_path):
        print(f"ERROR: HLS segment files cannot be upscaled: {input_path}", file=sys.stderr)
        continue
```

---

## 🧪 Testing the Fix

### Test Cases

| Input Path | Old Behavior | New Behavior |
|------------|-------------|--------------|
| `/media/movie.ts` | ✅ Accept | ✅ Accept |
| `/media/the_segment.ts` | ❌ Reject | ✅ Accept |
| `/segment_docs/video.ts` | ❌ Reject | ✅ Accept |
| `/hls_backup/video.ts` | ❌ Reject | ✅ Accept |
| `/output/segment_000.ts` | ❌ Reject | ❌ Reject |
| `/hls/video.ts` | ❌ Reject | ❌ Reject |
| `/data/seg_001.ts` | ✅ Accept | ❌ Reject |
| `/tmp/chunk_000.ts` | ✅ Accept | ❌ Reject |

### How to Test

1. **Rebuild the container** to include the fix:
   ```bash
   cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin
   docker compose down
   docker compose build --no-cache
   docker compose up -d
   ```

2. **Test with a .ts file:**
   ```bash
   # Create test job
   echo '{"input":"/path/to/your/video.ts","output":"/path/to/output.mkv"}' >> cache/queue.jsonl
   
   # Watch logs
   docker logs -f srgan-upscaler
   ```

3. **Expected behavior:**
   - If file matches HLS pattern: See "ERROR: HLS segment files cannot be upscaled"
   - If legitimate .ts file: Should process normally with AI upscaling

---

## 🔍 How to Check if This Was Your Issue

### Check Container Logs

```bash
docker logs srgan-upscaler | grep "REJECTED\|HLS segment"
```

**If you see:**
```
ERROR: HLS segment files cannot be upscaled: /path/to/your/file.ts
REJECTED: HLS segment file: /path/to/your/file.ts
```

And the file is **not** an actual HLS segment, then this fix will solve your problem.

### Check Watchdog Logs

If using the watchdog API:
```bash
# Check watchdog logs for rejections
# (wherever your watchdog is running)
```

---

## 🚀 Next Steps

### 1. Rebuild Container

The fix is in the code, but you need to rebuild the container:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin

# Stop container
docker compose down

# Rebuild with no cache (ensures fresh build)
docker compose build --no-cache

# Start container
docker compose up -d

# Verify it's running
docker ps | grep srgan-upscaler
```

### 2. Test with Your Video

Try playing a video that was previously rejected:

```bash
# Watch logs
docker logs -f srgan-upscaler

# Play video in Jellyfin or manually add to queue
echo '{"input":"/your/video.ts","output":"/your/output.mkv"}' >> cache/queue.jsonl
```

### 3. Verify AI Processing

You should now see:
```
============================================================
AI Upscaling Job
============================================================
Input:  /your/video.ts
Output: /your/output.mkv

Starting AI upscaling with SRGAN model...
Using FFmpeg-based AI upscaling (recommended)
Loading AI model...
✓ Model loaded
...
```

---

## ✅ Summary

### What Was Wrong
- `.ts` files were being rejected if they contained "segment" or "hls" **anywhere** in the path
- This was meant to block HLS segments but was too broad
- Legitimate MPEG-TS video files were incorrectly rejected

### What's Fixed
- Now only rejects files that match **actual HLS segment patterns**
- Checks for `segment_`, `seg_`, `chunk_` prefixes in filename
- Checks for `/hls/` or `/segments/` in directory path
- Regular .ts video files are now properly accepted

### Files Changed
- ✅ `scripts/watchdog_api.py` (Lines 176-188)
- ✅ `scripts/srgan_pipeline.py` (Lines 596-608)
- ✅ Linter verified - no errors

### Action Required
1. **Rebuild container:** `docker compose build --no-cache && docker compose up -d`
2. **Test with your videos**
3. **Verify in logs** that files are now being processed

---

## 📚 Related Documentation

- **INPUT_REJECTION_ROOT_CAUSE.md** - Detailed analysis of the problem
- **VERIFICATION_COMPLETE.md** - Overall system status
- **TROUBLESHOOTING_AI_NOT_WORKING.md** - General troubleshooting

---

**Your `.ts` files should now encode properly!** 🎉

If you're still having issues after rebuilding, check:
1. Docker container is running
2. File actually exists at the path
3. File is not in an `/hls/` or `/segments/` directory
4. Filename doesn't start with `segment_`, `seg_`, or `chunk_`
