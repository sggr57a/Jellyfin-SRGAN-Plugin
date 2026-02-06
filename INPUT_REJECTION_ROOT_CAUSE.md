# Input Not Getting Encoded - Root Cause Analysis

## 🔴 ROOT CAUSE IDENTIFIED

The code is **rejecting valid video files** because of overly aggressive `.ts` file filtering.

### The Problem

**Location 1:** `scripts/watchdog_api.py` (Line 176-179)
```python
# Reject .ts segment files (they're HLS segments, not transport streams)
if input_lower.endswith('.ts') and ('/segment' in input_lower or 'hls' in input_lower):
    logger.error(f"REJECTED: HLS segment file: {input_file}")
    return False, {"error": "HLS segments cannot be upscaled"}
```

**Location 2:** `scripts/srgan_pipeline.py` (Line 597-599)
```python
# Reject HLS segment files
if input_lower.endswith('.ts') and ('/segment' in input_lower or 'hls' in input_lower):
    print(f"ERROR: HLS segment files cannot be upscaled: {input_path}", file=sys.stderr)
    continue
```

### What This Does

The code checks if a file:
1. Ends with `.ts` AND
2. Contains `/segment` OR `hls` in the path

**If BOTH conditions are true, the file is REJECTED.**

### The Issue

This is TOO AGGRESSIVE and rejects legitimate files:

❌ **REJECTED (incorrectly):**
- `/mnt/media/Movies/segment_name_movie.ts` - Contains "segment" in filename
- `/mnt/hls-content/movie.ts` - Contains "hls" in directory path
- `/media/My Videos/the_segment.ts` - Contains "segment" in filename

✅ **SHOULD BE REJECTED (HLS segments):**
- `/data/upscaled/hls/segment_000.ts` - Actual HLS segment
- `/tmp/stream/segment_001.ts` - Actual HLS segment
- `/output/hls/segment_002.ts` - Actual HLS segment

### Root Cause

The filter was designed to prevent HLS **streaming segments** from being upscaled (since they're temporary chunks), but it's catching **any file** that happens to have "segment" or "hls" in its path, even if it's a legitimate video file.

---

## 🔧 SOLUTION

We need to make the filter MORE SPECIFIC to only reject actual HLS segments, not all `.ts` files.

### Better Detection Logic

HLS segments have specific characteristics:
1. Named like `segment_NNN.ts` or `seg_NNN.ts` or `chunk_NNN.ts`
2. Located in HLS output directories (usually `/hls/`, `/segments/`, etc.)
3. Part of a playlist (`.m3u8` file nearby)

### Fixed Code

Replace the overly broad check with a more specific one:

```python
# Reject HLS segment files (more specific check)
if input_lower.endswith('.ts'):
    basename = os.path.basename(input_lower)
    # Check if filename matches HLS segment pattern
    if ('segment_' in basename or 
        'seg_' in basename or 
        'chunk_' in basename or
        '/hls/' in input_lower.replace('\\', '/')):
        logger.error(f"REJECTED: HLS segment file: {input_file}")
        return False, {"error": "HLS segments cannot be upscaled"}
```

This checks:
1. If filename starts with `segment_`, `seg_`, or `chunk_` - typical HLS naming
2. OR if path contains `/hls/` directory - typical HLS output location

This will:
- ✅ Allow: `/media/Movies/the_segment.ts` (doesn't match pattern)
- ✅ Allow: `/content/movie.ts` (doesn't match pattern)
- ❌ Reject: `/output/hls/segment_000.ts` (matches pattern)
- ❌ Reject: `/tmp/seg_001.ts` (matches pattern)

---

## 📊 Impact Assessment

### Files Currently Being Rejected

If you have video files with `.ts` extension that contain:
- "segment" anywhere in the path (e.g., `/media/segment1/movie.ts`)
- "hls" anywhere in the path (e.g., `/hls_backup/movie.ts`)

They are being **silently rejected** and not processed.

### How to Check

Look for this in container logs:
```
ERROR: HLS segment files cannot be upscaled: /path/to/file.ts
```

Or in watchdog logs:
```
REJECTED: HLS segment file: /path/to/file.ts
```

---

## 🚀 Files That Need Fixing

1. **scripts/watchdog_api.py** (Line 176-179)
2. **scripts/srgan_pipeline.py** (Line 597-599)

Both need the improved detection logic.

---

## 📝 Next Steps

I'll create the fixed versions of these files with the improved HLS segment detection.
