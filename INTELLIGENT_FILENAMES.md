# Intelligent Filename Generation

## ✨ Automatic Resolution and HDR Tagging

The pipeline now **automatically renames output files** to include the new resolution and HDR status!

---

## 🎯 What It Does

### Automatic Tagging

When upscaling completes, the output filename includes:

1. ✅ **New resolution tag** (480p, 720p, 1080p, 1440p, 2160p)
2. ✅ **HDR tag** (if HDR metadata detected)
3. ✅ **Old tags removed** (old resolution, old quality tags)
4. ✅ **Clean formatting** (proper spacing, brackets)

---

## 📝 Examples

### Standard Upscaling

```
Input:  Movie (2020) [720p].mkv
Output: Movie (2020) [2160p].mkv
```

### With HDR

```
Input:  Movie (2020) [1080p].mkv (contains HDR10 metadata)
Output: Movie (2020) [2160p] [HDR].mkv
```

### Compound Tags

```
Input:  Back to the Future (1985) [Bluray-1080p].mp4
Output: Back to the Future (1985) [Bluray] [2160p].mkv
```

### No Previous Tags

```
Input:  Movie (2020).mkv
Output: Movie (2020) [2160p].mkv
```

### Multiple Old Tags

```
Input:  Old Movie [HD] [720p] [SD].avi
Output: Old Movie [2160p].mkv
```

### HDR Content

```
Input:  Show S01E01 [1080p] [HDR10].mkv
Output: Show S01E01 [2160p] [HDR].mkv
```

---

## 🔍 How It Works

### 1. Detect Input Resolution

Uses `ffprobe` to analyze input video:

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,color_space,color_transfer \
  input.mkv
```

**Gets:**
- Width/height (e.g., 1920x1080)
- Color space (e.g., bt2020)
- Color transfer (e.g., smpte2084 for HDR10)

### 2. Calculate Output Resolution

```python
scale_factor = 2.0  # From SRGAN_SCALE_FACTOR
target_height = input_height * scale_factor

# 1080 * 2.0 = 2160 (4K)
```

### 3. Detect HDR

Checks for HDR indicators:

- ✅ `color_transfer = smpte2084` (HDR10)
- ✅ `color_transfer = arib-std-b67` (HLG)
- ✅ `color_space = bt2020` (Wide color gamut)
- ✅ `color_primaries = bt2020` (HDR color space)

### 4. Remove Old Tags

Strips existing quality tags:

**Resolution tags removed:**
- `480p`, `576p`, `720p`, `1080p`, `1440p`, `2160p`
- `4K`, `2K`, `HD`, `FHD`, `UHD`, `SD`
- Compound: `Bluray-1080p`, `WEB-720p`

**HDR tags removed:**
- `HDR`, `HDR10`, `Dolby Vision`, `HLG`

### 5. Add New Tags

Appends to filename:

```
[resolution] [HDR if detected]
```

---

## 📊 Resolution Labels

| Height | Label | Common Name |
|--------|-------|-------------|
| 2160+ | `2160p` | 4K / UHD |
| 1440-2159 | `1440p` | 2K / QHD |
| 1080-1439 | `1080p` | Full HD |
| 720-1079 | `720p` | HD |
| 576-719 | `576p` | SD |
| 480-575 | `480p` | SD |
| < 480 | `{height}p` | Custom |

---

## 🎨 HDR Detection

### HDR10

Most common HDR format:

```
color_transfer: smpte2084
color_space: bt2020
→ Tagged as: [HDR]
```

### HLG (Hybrid Log-Gamma)

Broadcast HDR:

```
color_transfer: arib-std-b67
→ Tagged as: [HDR]
```

### Dolby Vision

Advanced HDR (becomes HDR in output):

```
Input: Movie [Dolby Vision].mkv
Output: Movie [2160p] [HDR].mkv
```

---

## ⚙️ Configuration

### Scale Factor

Controls output resolution:

```yaml
# docker-compose.yml
environment:
  - SRGAN_SCALE_FACTOR=2.0  # 2x upscale (default)
```

**Examples:**
- `1.5` - 720p → 1080p
- `2.0` - 1080p → 2160p (4K)
- `3.0` - 720p → 2160p (4K)
- `4.0` - 540p → 2160p (4K)

### Output Format

```yaml
environment:
  - OUTPUT_FORMAT=mkv  # or "mp4"
```

---

## 🧪 Testing

### Test Script

```bash
# Test filename generation
python3 scripts/test_filename_generation.py

# All tests should pass:
# Results: 10 passed, 0 failed
```

### Manual Test

```bash
# Test with a real file
./scripts/test_direct_output.sh '/mnt/media/Movie [720p].mp4' mkv

# Output will be: Movie [2160p].mkv (or [2160p] [HDR].mkv if HDR)
```

---

## 📁 Output Examples

### Movie Library

```
upscaled/
├── Inception (2010) [2160p] [HDR].mkv
├── The Matrix (1999) [2160p].mkv
├── Blade Runner 2049 (2017) [2160p] [HDR].mkv
└── Interstellar (2014) [2160p] [HDR].mkv
```

### TV Shows

```
upscaled/
├── Breaking Bad S01E01 [2160p].mkv
├── The Office S02E03 [1080p].mkv
├── Game of Thrones S01E01 [2160p] [HDR].mkv
└── Stranger Things S04E01 [2160p] [HDR].mkv
```

---

## 🔍 Verification

### Check Video Info

```bash
# After upscaling, check output
ffprobe -hide_banner upscaled/Movie*.mkv

# Look for:
# Stream #0:0: Video: hevc ... 3840x2160
# (confirms 2160p)

# color_transfer=smpte2084
# (confirms HDR if tagged)
```

### Check Filename

```bash
ls -lh upscaled/

# Should show filenames with proper tags:
# Movie (2020) [2160p] [HDR].mkv
```

---

## 🎬 Integration with Jellyfin

### Automatic Library Organization

Files are named to match Jellyfin conventions:

```
Movie (2020) [2160p] [HDR].mkv
→ Jellyfin recognizes:
  - Title: Movie
  - Year: 2020
  - Resolution: 2160p (4K)
  - HDR: Yes
```

### Multiple Versions

Keep different quality versions:

```
library/
├── Movie (2020) [720p].mkv          (original)
├── Movie (2020) [1080p].mkv         (another source)
└── Movie (2020) [2160p] [HDR].mkv   (upscaled)
```

Jellyfin shows all versions for selection!

---

## 🛠️ Advanced Configuration

### Custom Resolution Calculation

Override target resolution:

```bash
# In job queue
echo '{"input":"movie.mp4","output":"./upscaled/movie.mkv","width":3840,"height":2160}' >> cache/queue.jsonl

# Filename will be: movie [2160p].mkv
```

### Preserve Custom Tags

The system preserves non-resolution tags:

```
Input:  Movie [Bluray] [REMUX] [DTS-HD] [720p].mkv
Output: Movie [Bluray] [REMUX] [DTS-HD] [2160p].mkv
```

Only resolution/HDR tags are modified!

---

## 📊 Tag Priority

### Removal Order

1. Old resolution tags (480p-2160p, 4K, HD, etc.)
2. Old HDR tags (HDR, HDR10, Dolby Vision)
3. Cleanup extra spaces/brackets

### Addition Order

1. New resolution tag `[2160p]`
2. HDR tag if detected `[HDR]`

### Result Format

```
Movie Name (Year) [Other Tags] [Resolution] [HDR]
```

---

## 🐛 Troubleshooting

### Filename Not Updated

**Check logs:**
```bash
docker logs srgan-upscaler | grep -i "output\|resolution\|hdr"
```

**Should show:**
```
Target resolution: 2160p
HDR: Detected and tagged
Output: /data/upscaled/Movie [2160p] [HDR].mkv
```

### Wrong Resolution Tag

**Verify input:**
```bash
ffprobe input.mkv 2>&1 | grep "Video:"

# Should show dimensions like: 1920x1080
```

**Check scale factor:**
```bash
docker compose exec srgan-upscaler printenv SRGAN_SCALE_FACTOR

# Should show: 2.0
```

### HDR Not Detected

**Check input metadata:**
```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=color_transfer,color_space \
  -of default=noprint_wrappers=1 input.mkv
```

**HDR indicators:**
- `color_transfer=smpte2084` (HDR10)
- `color_transfer=arib-std-b67` (HLG)
- `color_space=bt2020` (Wide gamut)

If these aren't present, input is SDR (not HDR).

### Multiple Resolution Tags

**Shouldn't happen, but if it does:**
```bash
# The regex patterns remove all standard tags
# Report as bug if you see:
# Movie [1080p] [2160p].mkv
```

---

## 🎯 Summary

**Automatic filename intelligence:**
- ✅ Detects input resolution
- ✅ Calculates output resolution
- ✅ Detects HDR metadata
- ✅ Removes old quality tags
- ✅ Adds new resolution tag
- ✅ Adds HDR tag if applicable
- ✅ Clean, consistent naming

**Examples:**
```
Movie [720p].mkv → Movie [2160p].mkv
Movie [1080p].mkv (HDR) → Movie [2160p] [HDR].mkv
Back to the Future [Bluray-1080p].mp4 → Back to the Future [Bluray] [2160p].mkv
```

**No manual renaming needed!** 🎉
