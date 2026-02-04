# Direct File Output Mode

## 🎯 Major Change: Raw MKV/MP4 Output

The pipeline now outputs **direct MKV or MP4 files** instead of HLS streams.

---

## ✨ What Changed

### Before (HLS Streaming)
```
Input: movie.mp4
Output: 
  ├─ movie.ts (final file)
  └─ hls/movie/
      ├─ stream.m3u8 (playlist)
      ├─ segment_000.ts
      ├─ segment_001.ts
      └─ ...
```

**Issues:**
- Complex dual output
- HLS overhead
- TS container limitations
- Required cleanup
- Segments to manage

### After (Direct Output)
```
Input: movie.mp4
Output: movie.mkv  (single high-quality file)
```

**Benefits:**
- ✅ Single file output
- ✅ Better quality (no HLS overhead)
- ✅ Standard container format
- ✅ All audio tracks preserved
- ✅ All subtitle tracks preserved
- ✅ Works with any player
- ✅ Simpler pipeline

---

## 🎬 Supported Output Formats

### MKV (Matroska) - Recommended

```bash
OUTPUT_FORMAT=mkv
```

**Best for:**
- ✅ Maximum compatibility
- ✅ Multiple audio tracks
- ✅ Multiple subtitle tracks
- ✅ Chapters
- ✅ Attachments (fonts, covers)
- ✅ Any codec combination

**Characteristics:**
- Open standard
- Unlimited tracks
- Best quality preservation
- **Recommended default**

### MP4 (MPEG-4)

```bash
OUTPUT_FORMAT=mp4
```

**Best for:**
- ✅ Web streaming (faststart enabled)
- ✅ Maximum device compatibility
- ✅ iOS/Apple devices
- ✅ Smart TVs
- ✅ Browsers

**Characteristics:**
- Widely compatible
- Good streaming support
- Some codec limitations
- Good choice for Jellyfin

---

## ⚙️ Configuration

### Set Output Format

Edit `docker-compose.yml`:

```yaml
environment:
  - OUTPUT_FORMAT=mkv  # or "mp4"
```

**Options:**
- `mkv` - Matroska (default, recommended)
- `mp4` - MPEG-4

### Restart to Apply

```bash
docker compose restart srgan-upscaler
```

---

## 📊 What's Preserved

### Video
- ✅ HEVC/H.265 (NVENC encoded)
- ✅ 2x upscaled resolution
- ✅ High quality (CQ 23)
- ✅ HDR metadata (if present)

### Audio
- ✅ **All audio tracks** copied
- ✅ Original codecs preserved
- ✅ All channels (stereo, 5.1, 7.1, Atmos)
- ✅ Multiple languages

### Subtitles
- ✅ **All subtitle tracks** copied
- ✅ SRT, ASS, SSA, VobSub, PGS
- ✅ Multiple languages
- ✅ Forced/default flags preserved

### Metadata
- ✅ Title
- ✅ Language tags
- ✅ Track names
- ✅ Default/forced flags

---

## 🚀 Usage

### Automatic (via Jellyfin)

Just play a video in Jellyfin:
1. Webhook triggers watchdog
2. Watchdog queues job
3. Container processes video
4. Outputs to `./upscaled/filename.mkv`
5. Done!

### Manual Queue

```bash
# MKV output
echo '{"input":"/mnt/media/movie.mp4","output":"./upscaled/movie.mkv","streaming":false}' >> cache/queue.jsonl

# MP4 output
echo '{"input":"/mnt/media/movie.mp4","output":"./upscaled/movie.mp4","streaming":false}' >> cache/queue.jsonl
```

### Test Script

```bash
# Test with a file
./scripts/test_direct_output.sh '/mnt/media/movie.mp4' mkv

# Or MP4
./scripts/test_direct_output.sh '/mnt/media/movie.mp4' mp4
```

---

## 📁 Output Location

Default: `./upscaled/`

```
upscaled/
├── Movie (2020).mkv
├── Show S01E01.mkv
├── Documentary.mkv
└── ...
```

Configure in `docker-compose.yml`:
```yaml
environment:
  - UPSCALED_DIR=/data/upscaled
```

---

## 🔍 Verification

### Check Output File

```bash
# List upscaled files
ls -lh /root/Jellyfin-SRGAN-Plugin/upscaled/

# Get file info
mediainfo /root/Jellyfin-SRGAN-Plugin/upscaled/movie.mkv

# Or with ffprobe
ffprobe -hide_banner /root/Jellyfin-SRGAN-Plugin/upscaled/movie.mkv
```

### Check Logs

```bash
docker logs srgan-upscaler | tail -50
```

**You should see:**
```
Using direct file mode (FFmpeg)
Starting direct file upscale:
  Input:  /mnt/media/movie.mp4
  Output: /root/Jellyfin-SRGAN-Plugin/upscaled/movie.mkv
  Format: MKV
  Video:  hevc_nvenc (quality preset)
  Audio:  Copy all streams
  Subs:   Copy all streams

[Processing...]

✓ Upscaling complete: /root/Jellyfin-SRGAN-Plugin/upscaled/movie.mkv
```

---

## 📊 Quality Comparison

### Video Quality

**MKV and MP4 output identical quality:**
- HEVC/H.265 codec
- NVENC CQ 23 (constant quality)
- Full resolution upscale
- No re-encoding of audio/subs

### File Size

**Typical sizes (2-hour movie):**

| Source | Output | Size | Bitrate |
|--------|--------|------|---------|
| 1080p 8GB | 4K MKV | 12-18GB | ~15 Mbps |
| 1080p 8GB | 4K MP4 | 12-18GB | ~15 Mbps |
| 720p 4GB | 1080p MKV | 6-9GB | ~8 Mbps |

*Sizes depend on source quality and complexity*

---

## 🎬 Playback

### In Jellyfin

Just add the upscaled file to your library:

```bash
# If output is in Jellyfin library folder
# Jellyfin will auto-detect it

# Or link to library
ln -s /root/Jellyfin-SRGAN-Plugin/upscaled/movie.mkv /mnt/media/Movies/movie_4K.mkv

# Scan library in Jellyfin
```

### Direct Playback

Both formats work with:
- ✅ VLC
- ✅ MPV
- ✅ MPC-HC
- ✅ Jellyfin
- ✅ Plex
- ✅ Kodi
- ✅ Web browsers (MP4 with faststart)
- ✅ Smart TVs
- ✅ Mobile devices

---

## 🔧 Advanced Configuration

### Custom Output Path

```yaml
environment:
  - UPSCALED_DIR=/mnt/storage/upscaled
```

### Quality Settings

```yaml
environment:
  # Video quality (lower = better, 0-51)
  - SRGAN_FFMPEG_CQ=23  # NVENC quality
  
  # Encoder preset
  - SRGAN_FFMPEG_PRESET=p4  # p1-p7 (p7 = slowest, best quality)
```

### Hardware Acceleration

```yaml
environment:
  - SRGAN_FFMPEG_HWACCEL=1  # Use GPU decoding
  - SRGAN_FFMPEG_ENCODER=hevc_nvenc  # GPU encoding
```

---

## 🐛 Troubleshooting

### Output File Not Created

```bash
# Check logs for errors
docker logs srgan-upscaler | grep -i error

# Check if job was queued
cat cache/queue.jsonl

# Check output directory exists
ls -la upscaled/
```

### Wrong Format Output

```bash
# Check configuration
docker compose exec srgan-upscaler printenv OUTPUT_FORMAT

# Should show "mkv" or "mp4"
```

### File Size Too Large

```bash
# Increase compression (lower quality)
# Edit docker-compose.yml:
- SRGAN_FFMPEG_CQ=28  # Higher number = smaller file

# Restart
docker compose restart
```

### File Size Too Small (Low Quality)

```bash
# Decrease compression (higher quality)
# Edit docker-compose.yml:
- SRGAN_FFMPEG_CQ=18  # Lower number = larger file, better quality

# Restart
docker compose restart
```

---

## 📋 Migration from HLS Mode

If you have old HLS output:

```bash
# Clean up old HLS directories
rm -rf /root/Jellyfin-SRGAN-Plugin/upscaled/hls/

# Old .ts files can be kept or deleted
# They're the final output from HLS mode
```

New jobs will automatically use direct output mode.

---

## 🎯 Summary

**Key Changes:**
- ✅ Single file output (MKV or MP4)
- ✅ No more HLS complexity
- ✅ All tracks preserved
- ✅ Better quality
- ✅ Simpler workflow

**Configuration:**
```yaml
environment:
  - OUTPUT_FORMAT=mkv  # or "mp4"
```

**Output:**
```
./upscaled/filename.mkv  # Single high-quality file
```

**Test:**
```bash
./scripts/test_direct_output.sh '/path/to/video.mp4' mkv
```

**Much simpler and better quality!** 🚀
