# CRITICAL: Clear Job Queue Immediately

## 🚨 ERROR: `.ts` Output Still Being Used

```
ValueError: Unsupported output format: .ts. Only .mkv and .mp4 supported.
```

**Cause:** Old jobs in the queue still have `.ts` output paths from before we removed TS support.

---

## ✅ Solution: Clear the Queue

### On Your Server - RUN THIS NOW:

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Clear the job queue
./scripts/clear_queue.sh

# Output should show:
# Clearing job queue: ./cache/queue.jsonl
# ✓ Backed up to: ./cache/queue.jsonl.backup.20260201_120000
# ✓ Queue cleared
# All old jobs removed. New jobs will use direct MKV/MP4 output only.
```

---

## 🔍 Verify Queue is Clear

```bash
# Check queue file
cat /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl

# Should be empty (no output)
```

---

## 🚀 Restart and Test

```bash
# Restart watchdog to ensure clean state
docker compose restart srgan-watchdog-api

# Test with a new video
# 1. Play a video in Jellyfin
# 2. Check logs

docker logs -f srgan-upscaler
```

**Should now show MKV output:**
```
Output container format: matroska (.mkv)
```

**NOT:**
```
❌ .ts output
```

---

## 📋 What the Script Does

```bash
#!/bin/bash
# scripts/clear_queue.sh

QUEUE_FILE="${SRGAN_QUEUE_FILE:-./cache/queue.jsonl}"

if [[ -f "$QUEUE_FILE" ]]; then
    # Backup old queue
    backup_file="${QUEUE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$QUEUE_FILE" "$backup_file"
    
    # Clear the queue
    > "$QUEUE_FILE"
    
    echo "✓ Queue cleared"
fi
```

**Safe:** Backs up old queue before clearing.

---

## 🚨 Why This Happened

### Old Queue Entries

Before we removed TS support, the queue had jobs like:

```json
{"input": "/mnt/media/Movie.mp4", "output": "/mnt/media/Movie.ts", "streaming": true}
                                                              ^^^ TS file!
```

These old jobs persist until cleared.

---

## 🎯 After Clearing

New jobs will be:

```json
{"input": "/mnt/media/Movie [1080p].mkv", "output": "/mnt/media/Movie_upscaled.mkv", "streaming": false}
                                                                                  ^^^ MKV file!
```

Then intelligent naming renames to:
```
/mnt/media/Movie [2160p] [HDR].mkv
```

---

## ⚠️ Important Notes

1. **Queue persists across restarts** - Docker volumes preserve it
2. **Must manually clear** - No automatic cleanup
3. **Safe operation** - Creates backup first
4. **One-time fix** - Only needed once

---

## 🔍 Manual Queue Inspection

If you want to see what's in the queue:

```bash
# View queue contents
cat /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl

# Count jobs
wc -l /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl

# Check for .ts outputs
grep "\.ts" /root/Jellyfin-SRGAN-Plugin/cache/queue.jsonl
```

---

## 🎯 Quick Fix Checklist

- [ ] Run `./scripts/clear_queue.sh`
- [ ] Verify queue is empty: `cat cache/queue.jsonl`
- [ ] Restart watchdog: `docker compose restart srgan-watchdog-api`
- [ ] Test with new video playback
- [ ] Check logs show `.mkv` output
- [ ] Verify upscaling works

---

## 🚀 Complete Commands

Copy and paste this:

```bash
cd /root/Jellyfin-SRGAN-Plugin

# Clear queue
./scripts/clear_queue.sh

# Verify cleared
cat cache/queue.jsonl
# (should be empty)

# Restart services
docker compose restart srgan-watchdog-api
docker compose restart srgan-upscaler

# Watch logs
docker logs -f srgan-upscaler

# Now play a video in Jellyfin
# Should see: Output container format: matroska (.mkv)
```

---

## 🎯 Summary

**Problem:** Old `.ts` jobs in queue

**Solution:** Clear queue with provided script

**Commands:**
```bash
./scripts/clear_queue.sh
docker compose restart srgan-watchdog-api
```

**Result:** New jobs will use MKV/MP4 only! ✅
