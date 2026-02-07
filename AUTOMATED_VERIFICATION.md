# 🔧 AUTOMATED VERIFICATION SYSTEM

## Overview

The `install_all.sh` script now includes **comprehensive automated verification** that runs all diagnostic and test scripts automatically during installation. You don't need to run any verification scripts separately.

---

## What Gets Verified Automatically

### Step 13: Comprehensive Verification (NEW)

The installer now runs 7 automated tests:

#### 1. **Feature Verification** ✅
- Runs `verify_all_features.sh` automatically
- Checks all 10 features (HLS rejection, AI-only mode, intelligent filenames, etc.)
- Reports pass/fail for each feature
- Logs results to `/tmp/feature_verification.log`

#### 2. **Pipeline Diagnostics** ✅
- Runs `debug_pipeline.sh` automatically
- Performs 10-point diagnostic check
- Verifies container, process, GPU, model, queue
- Logs results to `/tmp/pipeline_diagnostics.log`

#### 3. **AI & GPU Diagnostics** ✅
- Runs `diagnose_ai.sh` automatically
- Checks AI model availability
- Verifies GPU access and CUDA
- Tests PyTorch and NVIDIA encoder
- Logs results to `/tmp/ai_diagnostics.log`

#### 4. **Docker Container Health** ✅
- Container running status
- GPU accessibility from container
- Model file existence and size
- Pipeline process status
- Media directory accessibility
- **Score: X/5** displayed

#### 5. **Service Health** ✅
- Watchdog API service status
- Auto-fix timer status
- API endpoint responsiveness
- **Score: X/3** displayed

#### 6. **Configuration Validation** ✅
- AI upscaling enabled check
- Volume mount permissions (read-write)
- Output format configuration
- Environment file existence
- **Score: X/4** displayed

#### 7. **Python Scripts Health** ✅
- Shebang line verification
- Key scripts availability
- Executable permissions
- **Score: X/4** displayed

---

## Automatic Report Generation

### Step 14: Installation Report (NEW)

After all tests, an installation report is automatically generated:

**Location:** `INSTALLATION_REPORT.txt` (in repo root)

**Contents:**
- Verification summary for all tests
- Service status
- Configuration details
- Quick command reference
- Next steps
- Support information

---

## Health Score System

### Overall Health Score

The installer calculates an overall health score:

**Maximum Score:** 17 points

**Score Breakdown:**
- Container Health: 5 points
- Service Health: 3 points
- Configuration: 4 points
- Python Scripts: 4 points
- Auto-fix: 1 point

**Rating Scale:**
```
14-17 points: ✓✓✓ EXCELLENT - System fully operational
10-13 points: ⚠ GOOD - Minor issues, auto-fix will resolve
0-9 points:   ⚠ NEEDS ATTENTION - Run diagnostics
```

---

## What You See During Installation

### Example Output

```
================================================================================
Step 13: Running comprehensive verification and tests...
================================================================================

This will automatically verify all features, test the pipeline, and
diagnose any issues. This ensures everything is working before completion.

Test 1: Feature Verification
-----------------------------------------------------------
✓ Feature 1: HLS Stream Input Rejection
✓ Feature 2: AI-Only Mode (No FFmpeg Fallback)
✓ Feature 3: Intelligent Filename with Resolution & HDR
✓ Feature 4: Output to Same Directory as Input
✓ Feature 5: MKV/MP4 Output Only (No TS/HLS)
✓ Feature 6: Output Verification & Logging
✓ Feature 7: SRGAN_ENABLE Configuration
✓ Feature 8: Read-Write Volume Mount
✓ Feature 9: FFmpeg-based AI Implementation
✓ Feature 10: SRGAN Model File

Results: 10 passed, 0 failed

✓✓✓ All 10 features verified successfully

Test 2: Pipeline Diagnostics
-----------------------------------------------------------
✓ srgan-upscaler container is running
✓ Pipeline process is running
✓ Queue file exists
✓ Watchdog API service is running
✓ GPU is accessible
✓ Model file exists (901K)
✓ SRGAN_ENABLE: 1
✓ FFmpeg-based AI module imports successfully
✓ PyTorch 2.4.0 available
✓ CUDA available: True

✓ All diagnostic checks passed

Test 3: AI Model and GPU Diagnostics
-----------------------------------------------------------
[10-point AI diagnostic results...]

✓ AI model and GPU ready

Test 4: Docker Container Health Check
-----------------------------------------------------------
✓ Container is running
✓ GPU accessible from container
✓ Model file exists (901K)
✓ Pipeline process is running
✓ Media directory accessible (569 files)

Container health score: 5/5
✓ Container is healthy

Test 5: Service Health Check
-----------------------------------------------------------
✓ Watchdog API service running
✓ Auto-fix timer active
✓ Watchdog API responding

Service health score: 3/3
✓ Services are healthy

Test 6: Configuration Validation
-----------------------------------------------------------
✓ AI upscaling enabled
✓ Media volume mounted read-write
✓ Output format configured (MKV)
✓ Watchdog environment file exists

Configuration score: 4/4
✓ Configuration is valid

Test 7: Python Scripts Health Check
-----------------------------------------------------------
✓ srgan_pipeline.py has shebang
✓ your_model_file_ffmpeg.py has shebang
✓ your_model_file.py has shebang
✓ watchdog_api.py has shebang

Python health score: 4/4
✓ All Python scripts properly configured

================================================================================
Step 14: Generating installation report...
================================================================================

✓ Installation report generated
  Report saved to: /root/Jellyfin-SRGAN-Plugin/INSTALLATION_REPORT.txt

════════════════════════════════════════════════════════════════
VERIFICATION SUMMARY
════════════════════════════════════════════════════════════════

Overall Health Score: 17/17

✓✓✓ EXCELLENT - System is fully operational

════════════════════════════════════════════════════════════════

================================================================================
Installation Complete!
================================================================================

✓ Automated Verification Completed
  All tests and diagnostics have been run automatically
  Installation report: /root/Jellyfin-SRGAN-Plugin/INSTALLATION_REPORT.txt
```

---

## No Manual Scripts Needed

### Previously Required (OLD)

```bash
# Old way - had to run manually after installation
./scripts/verify_all_features.sh
./scripts/debug_pipeline.sh
./scripts/diagnose_ai.sh
# ... etc
```

### Now Automatic (NEW)

```bash
# New way - just run installer
./scripts/install_all.sh

# Everything runs automatically:
# ✓ Feature verification
# ✓ Pipeline diagnostics
# ✓ AI diagnostics
# ✓ Container health
# ✓ Service health
# ✓ Configuration validation
# ✓ Python scripts check
# ✓ Report generation
```

---

## When to Run Scripts Manually

You should only run diagnostic scripts manually if:

1. **Installation failed** - To diagnose specific issues
2. **After system changes** - To verify changes worked
3. **Troubleshooting** - To investigate specific problems
4. **Periodic checks** - Optional health checks

### Manual Commands

```bash
# Full feature verification
./scripts/verify_all_features.sh

# Pipeline diagnostics
./scripts/debug_pipeline.sh

# AI-specific checks
./scripts/diagnose_ai.sh

# Manual test with monitoring
./scripts/test_manual_queue.sh

# Complete workflow test
./scripts/test_complete_workflow.sh

# Run auto-fix manually
./scripts/autofix.sh
```

---

## What Each Test Does

### Test 1: Feature Verification

**Script:** `verify_all_features.sh`

**Checks:**
- HLS input rejection
- AI-only mode enforcement
- Intelligent filename generation
- Same directory output
- MKV/MP4 only output
- Verification & logging
- SRGAN enabled
- Read-write volume mount
- FFmpeg-based AI module
- Model file present

**Result:** Pass/fail for each feature + overall score

---

### Test 2: Pipeline Diagnostics

**Script:** `debug_pipeline.sh`

**Checks:**
- Container status and uptime
- Pipeline process running
- Queue file status
- Watchdog API status
- GPU access via nvidia-smi
- Model file size
- Environment variables
- Recent logs analysis
- AI module import test
- Volume mount test

**Result:** Detailed diagnostic report

---

### Test 3: AI Diagnostics

**Script:** `diagnose_ai.sh`

**Checks:**
- Container running
- SRGAN_ENABLE=1
- Model file valid
- PyTorch installed
- CUDA available
- GPU device detected
- FFmpeg with NVENC
- AI module imports
- Queue health
- Recent processing logs

**Result:** 10/10 checks with fixes if needed

---

### Test 4: Container Health

**Automatic checks:**
- Docker container running
- GPU accessible (nvidia-smi)
- Model file exists
- Pipeline process active
- Media directory mounted

**Score:** 5/5 for perfect health

---

### Test 5: Service Health

**Automatic checks:**
- Watchdog API systemd service
- Auto-fix timer systemd service
- API endpoint responding

**Score:** 3/3 for perfect health

---

### Test 6: Configuration

**Automatic checks:**
- SRGAN_ENABLE=1 in docker-compose.yml
- Volume mount is read-write (:rw)
- OUTPUT_FORMAT configured
- Environment file exists

**Score:** 4/4 for valid config

---

### Test 7: Python Scripts

**Automatic checks:**
- Shebang lines present
- Key scripts exist
- Executable permissions

**Score:** 4/4 for healthy scripts

---

## Log Files

### Verification Logs

During installation, logs are saved to:

```
/tmp/feature_verification.log     - Feature test results
/tmp/pipeline_diagnostics.log     - Pipeline diagnostic output
/tmp/ai_diagnostics.log           - AI diagnostic output
```

### Permanent Logs

After installation:

```
/var/log/srgan-autofix.log        - Auto-fix activity
INSTALLATION_REPORT.txt            - Complete installation report
```

---

## Troubleshooting Low Scores

### If Container Health < 5

**Common issues:**
- Container not running → Run: `docker compose up -d`
- GPU not accessible → Restart Docker
- Model missing → Run: `./scripts/setup_model.sh`
- Pipeline not running → Check logs: `docker logs srgan-upscaler`

**Auto-fix:** Will resolve automatically within 5 minutes

---

### If Service Health < 3

**Common issues:**
- Watchdog not running → Run: `systemctl start srgan-watchdog-api`
- Auto-fix not enabled → Run: `systemctl start srgan-autofix.timer`
- API not responding → Check: `journalctl -u srgan-watchdog-api`

**Auto-fix:** Will restart services automatically

---

### If Configuration < 4

**Common issues:**
- SRGAN_ENABLE=0 → Edit docker-compose.yml, set to 1
- Volume read-only → Change to `:rw` in docker-compose.yml
- Missing env file → Re-run installer

**Manual fix:** Edit configuration files and restart

---

### If Python Scripts < 4

**Common issues:**
- Missing shebangs → Fixed in latest code
- Wrong permissions → Run: `chmod +x scripts/*.py`
- Files missing → Re-clone repository

**Should not happen:** Latest code has all fixes

---

## Benefits

✅ **No manual verification** - Everything runs automatically  
✅ **Comprehensive testing** - 7 different test suites  
✅ **Health scoring** - Clear pass/fail metrics  
✅ **Automatic report** - Complete installation summary  
✅ **Issue detection** - Problems found immediately  
✅ **Auto-fix integration** - Issues resolved automatically  
✅ **Detailed logs** - Easy troubleshooting  
✅ **Time saving** - No need to remember commands  

---

## Summary

**Old workflow:**
```
1. Run install_all.sh
2. Run verify_all_features.sh
3. Run debug_pipeline.sh
4. Run diagnose_ai.sh
5. Check each manually
6. Troubleshoot if needed
```

**New workflow:**
```
1. Run install_all.sh
   (Everything runs automatically)
2. Review INSTALLATION_REPORT.txt
3. Done!
```

**Result:** Installation is fully verified automatically with comprehensive testing and reporting! 🎉
