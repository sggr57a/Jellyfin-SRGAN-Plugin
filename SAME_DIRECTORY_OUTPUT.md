# Same Directory Output

## 📁 Upscaled Files Saved Alongside Originals

**Upscaled files are now saved in the SAME directory as the input files**, not in a separate `upscaled` directory.

---

## ✅ What Changed

### Before

```
/mnt/media/MOVIES/
  └── Movie (2020) [1080p].mkv        (original)

/root/Jellyfin-SRGAN-Plugin/upscaled/
  └── Movie (2020) [2160p].mkv        (upscaled - separate location)
```

**Issues:**
- Content separated from originals
- Risk of data loss if upscaled dir deleted
- Not visible to Jellyfin by default
- Extra configuration needed

### After

```
/mnt/media/MOVIES/
  ├── Movie (2020) [1080p].mkv        (original)
  └── Movie (2020) [2160p].mkv        (upscaled - same location!)
```

**Benefits:**
- ✅ Original and upscaled versions together
- ✅ No risk of losing upscaled files
- ✅ Immediately visible to Jellyfin
- ✅ Automatic library scanning
- ✅ Natural organization

---

## 🎯 How It Works

### 1. Input File Detected

```
Input: /mnt/media/MOVIES/Inception (2010) [1080p].mkv
```

### 2. Output Directory = Input Directory

```python
# watchdog_api.py
input_dir = os.path.dirname(input_file)
# Result: /mnt/media/MOVIES/
```

### 3. Intelligent Filename Generated

```python
# Pipeline generates intelligent filename
# Removes old resolution tags
# Adds new resolution and HDR tags

Output: /mnt/media/MOVIES/Inception (2010) [2160p] [HDR].mkv
```

### 4. Final Result

```
/mnt/media/MOVIES/
├── Inception (2010) [1080p].mkv      # Original (keep or delete)
└── Inception (2010) [2160p] [HDR].mkv # Upscaled (AI enhanced)
```

---

## 📚 Examples

### Movie Library

**Before upscaling:**
```
/mnt/media/MOVIES/
├── Blade Runner 2049 (2017)/
│   └── Blade Runner 2049 (2017) [Bluray-1080p].mkv
├── Interstellar (2014)/
│   └── Interstellar (2014) [1080p].mp4
└── The Matrix (1999)/
    └── The Matrix (1999) [720p].mkv
```

**After upscaling:**
```
/mnt/media/MOVIES/
├── Blade Runner 2049 (2017)/
│   ├── Blade Runner 2049 (2017) [Bluray-1080p].mkv     # Original
│   └── Blade Runner 2049 (2017) [Bluray] [2160p] [HDR].mkv  # Upscaled!
├── Interstellar (2014)/
│   ├── Interstellar (2014) [1080p].mp4                 # Original
│   └── Interstellar (2014) [2160p] [HDR].mkv           # Upscaled!
└── The Matrix (1999)/
    ├── The Matrix (1999) [720p].mkv                    # Original
    └── The Matrix (1999) [2160p].mkv                   # Upscaled!
```

### TV Shows

**Before upscaling:**
```
/mnt/media/TV/
└── Breaking Bad/
    └── Season 01/
        ├── S01E01 - Pilot [1080p].mkv
        ├── S01E02 - Cat's in the Bag [1080p].mkv
        └── S01E03 - And the Bag's in the River [1080p].mkv
```

**After upscaling:**
```
/mnt/media/TV/
└── Breaking Bad/
    └── Season 01/
        ├── S01E01 - Pilot [1080p].mkv              # Original
        ├── S01E01 - Pilot [2160p].mkv              # Upscaled!
        ├── S01E02 - Cat's in the Bag [1080p].mkv  # Original
        ├── S01E02 - Cat's in the Bag [2160p].mkv  # Upscaled!
        └── ...
```

---

## 🎬 Jellyfin Integration

### Multiple Versions Automatically Detected

Jellyfin recognizes both versions as the same item:

```
Movie (2020)
├── Version 1: 1080p (Original)      [5.2 GB]
└── Version 2: 2160p HDR (AI)        [8.7 GB]  ← Click to play this!
```

**User can choose which version to play!**

### How Jellyfin Sees It

1. **Library Scan** finds both files
2. **Name matching** groups them together
3. **Quality detection** identifies resolution/HDR
4. **User selects** which version to play

**Perfect integration - no extra configuration needed!**

---

## 🧹 Cleanup Strategy

### Keep Both Versions

```bash
# Do nothing - both files coexist
/mnt/media/MOVIES/
├── Movie [1080p].mkv     # Original (5GB)
└── Movie [2160p].mkv     # Upscaled (8GB)
```

**Pros:**
- Fallback if upscaled version has issues
- Can compare quality
- Multiple quality options

**Cons:**
- Uses more disk space (original + upscaled)

---

### Delete Original After Verification

```bash
# After verifying upscaled quality is good
rm "/mnt/media/MOVIES/Movie [1080p].mkv"

# Result: Only upscaled version remains
/mnt/media/MOVIES/
└── Movie [2160p].mkv     # Upscaled only
```

**Pros:**
- Saves disk space
- Clean library

**Cons:**
- Can't go back to original
- Should verify quality first

---

### Automated Cleanup Script

```bash
#!/bin/bash
# cleanup_originals.sh
# Delete original files after upscaling (BE CAREFUL!)

MEDIA_DIR="/mnt/media"

# Find all directories with both original and upscaled versions
find "$MEDIA_DIR" -type f -name "*[1080p]*" | while read original; do
    dir=$(dirname "$original")
    basename=$(basename "$original" | sed 's/\[1080p\]/[2160p]/')
    upscaled="$dir/$basename"
    
    # Check if upscaled version exists
    if [[ -f "$upscaled" ]]; then
        echo "Found pair:"
        echo "  Original: $original"
        echo "  Upscaled: $upscaled"
        
        # Verify upscaled file is valid
        if ffprobe "$upscaled" >/dev/null 2>&1; then
            echo "  → Deleting original (upscaled verified)"
            rm "$original"
        else
            echo "  → ERROR: Upscaled file invalid, keeping original"
        fi
    fi
done
```

**Use with caution! Test on a few files first.**

---

## 🔒 Safety Features

### No Overwriting

The intelligent filename generation ensures the upscaled version has a **different name** than the original:

```
Original:  Movie [1080p].mkv
Upscaled:  Movie [2160p].mkv  ← Different resolution tag
```

**The original is NEVER overwritten!**

### Already Exists Check

```python
# watchdog_api.py checks before queuing
if os.path.exists(output_path):
    logger.info(f"✓ Output already exists: {output_path}")
    return True, {"status": "ready", "file": output_path}
```

**If upscaled file exists, skips re-upscaling.**

---

## 📊 Disk Space Considerations

### Typical File Sizes

| Resolution | Bitrate | 2hr Movie | TV Episode (40min) |
|------------|---------|-----------|---------------------|
| 720p       | 3 Mbps  | 2.7 GB    | 900 MB              |
| 1080p      | 6 Mbps  | 5.4 GB    | 1.8 GB              |
| 2160p (4K) | 12 Mbps | 10.8 GB   | 3.6 GB              |

**Upscaling increases file size ~2x** (due to higher resolution encoding).

### Example: 100-Movie Library

**Original (1080p):** 100 movies × 5 GB = 500 GB  
**Upscaled (2160p):** 100 movies × 10 GB = 1,000 GB  
**Total (both):** 1,500 GB (1.5 TB)

**If you delete originals:** 1,000 GB (1 TB)

---

## ⚙️ Configuration

### No Configuration Needed!

The output directory is **automatically determined** from the input file path.

### Optional: Change Output Format

```yaml
# docker-compose.yml
environment:
  - OUTPUT_FORMAT=mkv  # or "mp4"
```

**That's it!** No `UPSCALED_DIR` needed.

---

## 🔍 Verification

### Check Where Files Are Saved

```bash
# After upscaling, check the input directory
ls -lh /mnt/media/MOVIES/

# Should show:
# Movie [1080p].mkv       (original)
# Movie [2160p].mkv       (upscaled - SAME DIR!)
```

### Check Jellyfin Library

1. Open Jellyfin
2. Navigate to the movie
3. Click "⋮" (More) → "Media Info"
4. Should show **2 versions**:
   - Version 1: 1080p
   - Version 2: 2160p HDR

---

## 🚨 Troubleshooting

### "Permission denied" Error

```
ERROR: Could not write to /mnt/media/MOVIES/
```

**Cause:** Docker container doesn't have write access to media directory.

**Fix:**

1. Check volume mount in docker-compose.yml:
```yaml
volumes:
  - /mnt/media:/mnt/media:rw  # ← Make sure :rw (read-write)
```

2. Check directory permissions:
```bash
# Should be writable by docker user
ls -ld /mnt/media/MOVIES/
# If not, fix permissions
sudo chmod 755 /mnt/media/MOVIES/
```

---

### Upscaled File Not in Jellyfin

**Cause:** Jellyfin hasn't scanned the new file yet.

**Fix:**

1. **Automatic:** Wait for next scheduled scan (default: every 12 hours)

2. **Manual:** Force library scan:
   - Jellyfin Dashboard → Libraries
   - Click "Scan Library" on your media library

3. **Instant:** Enable real-time monitoring:
   - Dashboard → Libraries → Edit library
   - ✅ Enable real-time monitoring

---

## 🎯 Summary

**What Changed:**

✅ Upscaled files saved in **same directory** as originals  
✅ No separate `upscaled` directory needed  
✅ Jellyfin automatically detects both versions  
✅ Original never overwritten (different filename)  
✅ Clean, natural organization  

**Example Result:**

```
/mnt/media/MOVIES/Inception (2010)/
├── Inception (2010) [1080p].mkv          # Original
└── Inception (2010) [2160p] [HDR].mkv    # AI upscaled
```

**In Jellyfin:** User can select which version to play!

---

## 🚀 Deploy

No changes needed to docker-compose.yml!

```bash
cd /root/Jellyfin-SRGAN-Plugin
git pull origin main

# Restart to apply changes
docker compose restart srgan-watchdog-api

# Test by playing a video in Jellyfin
# Upscaled version will appear in the same directory!
```

Done! 🎉
