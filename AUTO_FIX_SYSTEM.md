# 🔧 Automatic Error Detection and Recovery System

## Overview

The SRGAN pipeline now includes an **automatic error detection and recovery system** that runs every 5 minutes to detect and fix common issues without manual intervention.

---

## Features

### Automatic Detection & Fixing

The system automatically detects and fixes these issues:

1. **Container Crashes** → Auto-restart Docker container
2. **Pipeline Not Running** → Diagnose and restart with appropriate fix
3. **Watchdog API Stopped** → Auto-restart watchdog service
4. **GPU Not Accessible** → Restart Docker daemon and recreate container
5. **Model File Missing** → Auto-download SRGAN model
6. **Queue Stuck** → Clear queue with automatic backup
7. **Recent Processing Errors** → Run diagnostics and apply fixes

---

## Installation

The auto-fix system is **automatically installed** when you run:

```bash
./scripts/install_all.sh
```

It installs:
- `/scripts/autofix.sh` - The diagnostic and fix script
- Systemd service: `srgan-autofix.service`
- Systemd timer: `srgan-autofix.timer` (runs every 5 minutes)

---

## How It Works

### Automatic Schedule

```
Every 5 minutes:
  1. Check if container is running
  2. Check if pipeline process is active
  3. Check if watchdog API is running
  4. Check if GPU is accessible
  5. Check if model file exists
  6. Check queue health
  7. Check for recent processing errors
  8. Apply fixes if issues found
  9. Run post-fix verification
  10. Log results
```

### Cooldown Period

- Checks only run every 5 minutes minimum
- Prevents excessive resource usage
- Uses `/tmp/srgan-last-check` to track last run

### Logging

All actions logged to: `/var/log/srgan-autofix.log`

```bash
# View logs
tail -f /var/log/srgan-autofix.log

# Recent activity
tail -50 /var/log/srgan-autofix.log
```

---

## Manual Usage

### Run Auto-Fix Manually

```bash
# Run diagnostics and fixes immediately
/root/Jellyfin-SRGAN-Plugin/scripts/autofix.sh
```

### Check Timer Status

```bash
# Check if timer is active
systemctl status srgan-autofix.timer

# List timer schedule
systemctl list-timers srgan-autofix.timer
```

### Stop/Start/Restart

```bash
# Stop automatic checks
sudo systemctl stop srgan-autofix.timer

# Start automatic checks
sudo systemctl start srgan-autofix.timer

# Restart timer
sudo systemctl restart srgan-autofix.timer

# Disable (won't start on boot)
sudo systemctl disable srgan-autofix.timer

# Enable (start on boot)
sudo systemctl enable srgan-autofix.timer
```

---

## What Gets Fixed

### Issue 1: Container Not Running

**Detected when:**
- `docker ps` doesn't show `srgan-upscaler`

**Fix applied:**
```bash
docker compose down
docker compose up -d
```

**Verification:**
- Check if container is running after 5 seconds

---

### Issue 2: Pipeline Process Not Running

**Detected when:**
- Container is running but no `srgan_pipeline.py` process

**Diagnostic checks:**
- Model file missing → Run `setup_model.sh`
- GPU not available → Restart Docker daemon
- Import errors → Rebuild container with `--no-cache`
- Other issues → Generic container restart

**Fix applied:** Based on specific error found

---

### Issue 3: Watchdog API Not Running

**Detected when:**
- `systemctl is-active srgan-watchdog-api` returns inactive

**Fix applied:**
```bash
systemctl restart srgan-watchdog-api
```

**Verification:**
- Check service status after 2 seconds

---

### Issue 4: GPU Not Accessible

**Detected when:**
- `nvidia-smi` fails inside container

**Fix applied:**
```bash
systemctl restart docker
sleep 5
docker compose down
docker compose up -d
```

**Verification:**
- Run `nvidia-smi` inside container after fix

---

### Issue 5: Model File Missing

**Detected when:**
- `/app/models/swift_srgan_4x.pth` doesn't exist in container

**Fix applied:**
```bash
./scripts/setup_model.sh
```

**Verification:**
- Check if model file exists after download

---

### Issue 6: Queue Stuck

**Detected when:**
- Queue has more than 10 jobs

**Fix applied:**
1. Backup current queue to `cache/queue.jsonl.autobackup.TIMESTAMP`
2. Clear queue file
3. Log backup location

**Rationale:**
- Old jobs may be HLS/TS files (no longer supported)
- Stuck jobs prevent new jobs from processing
- Backup ensures no data loss

---

### Issue 7: Recent Processing Errors

**Monitored errors:**
- "AI model upscaling failed" → Run full diagnostics
- "Input file does not exist" → Check volume mounts
- "CUDA out of memory" → Restart container

**Fix applied:** Based on specific error type

---

## Example Log Output

```
[2026-02-07 10:05:00] ===== Auto-Fix Service Started =====
[2026-02-07 10:05:01] Running automated diagnostics...
[2026-02-07 10:05:02] Issue detected: Pipeline process not running
[2026-02-07 10:05:02] ERROR: Pipeline process not running. Checking logs...
[2026-02-07 10:05:03] ERROR: Model file missing. Running setup_model.sh...
[2026-02-07 10:05:45] ✓ Model file downloaded successfully
[2026-02-07 10:05:46] ✓ Container restarted successfully
[2026-02-07 10:05:46] Summary: Found 1 issues, fixed 1
[2026-02-07 10:05:46] Running post-fix verification...
[2026-02-07 10:05:50] Results: 10 passed, 0 failed
[2026-02-07 10:05:50] ✓ All checks passed. System healthy.
[2026-02-07 10:05:50] ===== Auto-Fix Service Completed =====
```

---

## Integration with Existing Tools

### Works Alongside

- **Watchdog API** - Auto-fix ensures it stays running
- **Pipeline** - Auto-fix ensures it stays healthy
- **Docker** - Auto-fix manages container lifecycle
- **Diagnostic tools** - Auto-fix calls them for verification

### Post-Fix Verification

After applying fixes, auto-fix runs:
```bash
./scripts/verify_all_features.sh
```

This ensures:
- All 10 features still working
- Configuration is correct
- System is healthy

---

## Disable Auto-Fix

If you want to disable automatic fixes:

```bash
# Stop and disable timer
sudo systemctl stop srgan-autofix.timer
sudo systemctl disable srgan-autofix.timer

# Verify it's stopped
systemctl status srgan-autofix.timer
```

You can still run manual diagnostics:
```bash
./scripts/debug_pipeline.sh
./scripts/autofix.sh
```

---

## Resource Usage

**CPU:** Negligible (runs for ~5-10 seconds every 5 minutes)
**Memory:** Minimal (bash script with some Docker commands)
**Disk:** Log file at `/var/log/srgan-autofix.log` (rotates automatically)
**Network:** None (all local checks)

**Priority:** Low (Nice=10, IOSchedulingClass=idle)

---

## Troubleshooting Auto-Fix

### Timer not running

```bash
# Check status
systemctl status srgan-autofix.timer

# Check logs
journalctl -u srgan-autofix.timer -n 50

# Restart
sudo systemctl restart srgan-autofix.timer
```

### Script errors

```bash
# Check script is executable
ls -l /root/Jellyfin-SRGAN-Plugin/scripts/autofix.sh

# Make executable if needed
chmod +x /root/Jellyfin-SRGAN-Plugin/scripts/autofix.sh

# Test manually
/root/Jellyfin-SRGAN-Plugin/scripts/autofix.sh
```

### Logs not appearing

```bash
# Check log file exists
ls -l /var/log/srgan-autofix.log

# Create if missing
sudo touch /var/log/srgan-autofix.log
sudo chmod 644 /var/log/srgan-autofix.log
```

---

## Customization

### Change Check Interval

Edit `/etc/systemd/system/srgan-autofix.timer`:

```ini
[Timer]
# Run every 10 minutes instead
OnBootSec=10min
OnUnitActiveSec=10min
AccuracySec=1min
```

Then reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart srgan-autofix.timer
```

### Add Custom Checks

Edit `/root/Jellyfin-SRGAN-Plugin/scripts/autofix.sh`:

```bash
# Add to run_diagnostics() function
# Check 7: Your custom check
if [[ custom_condition ]]; then
    ((ISSUES_FOUND++))
    log "Issue detected: Your issue"
    
    if fix_your_issue; then
        ((ISSUES_FIXED++))
    fi
fi
```

### Custom Fix Function

```bash
# Add to autofix.sh
fix_your_issue() {
    log "Fixing your issue..."
    
    # Your fix commands here
    
    if [[ fix_successful ]]; then
        log "✓ Issue fixed"
        return 0
    else
        log "✗ Fix failed"
        return 1
    fi
}
```

---

## Benefits

✅ **Hands-off operation** - System self-heals
✅ **Minimal downtime** - Issues fixed within 5 minutes
✅ **Comprehensive logging** - Track all fixes
✅ **Safe fixes** - Backups before destructive operations
✅ **Resource efficient** - Low CPU/memory impact
✅ **Configurable** - Adjust interval and checks
✅ **Manual override** - Run on-demand when needed

---

## Summary

The auto-fix system provides **automatic monitoring and recovery** for the SRGAN pipeline:

- **Installed by:** `./scripts/install_all.sh`
- **Runs:** Every 5 minutes via systemd timer
- **Fixes:** 7 common issues automatically
- **Logs:** `/var/log/srgan-autofix.log`
- **Status:** `systemctl status srgan-autofix.timer`
- **Manual:** `./scripts/autofix.sh`

**Result:** Reliable, self-healing upscaling pipeline with minimal intervention! 🎉
