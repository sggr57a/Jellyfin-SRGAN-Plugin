# install_all.sh Integration Improvements

Summary of enhancements to the automated installation script.

## What Changed

The `install_all.sh` script now provides a comprehensive, automated installation experience by integrating verification and model setup.

### Previous Behavior

**Before:**
```bash
./scripts/install_all.sh
# - Built Docker container
# - Started container
# - Installed systemd service
# - That's it

# User had to manually:
python3 scripts/verify_setup.py     # Check prerequisites
./scripts/setup_model.sh            # Setup AI model
python3 scripts/test_webhook.py     # Test installation
```

**Issues:**
- No prerequisite verification
- Users forgot to setup model
- No guidance after installation
- Limited feedback during install
- Users didn't know what to do next

### New Behavior

**Now:**
```bash
./scripts/install_all.sh
# Automatically:
# ✓ Step 1: Verifies system prerequisites
# ✓ Step 2: Builds Jellyfin plugin (if detected)
# ✓ Step 3: Prompts for AI model download
# ✓ Step 4: Builds Docker images
# ✓ Step 5: Starts container
# ✓ Step 6: Runs GPU detection (optional)
# ✓ Step 7: Cleans up files (optional)
# ✓ Step 8: Installs systemd service
# ✓ Shows completion summary with next steps
```

**Benefits:**
- Complete automated setup
- User knows if prerequisites are missing
- Optional model download prompt
- Clear progress indicators
- Helpful completion summary
- Guides user to next steps

## New Features

### 1. Integrated Verification (Step 1)

**Runs `verify_setup.py` automatically:**

```bash
Step 1: Verifying system prerequisites...
========================================================================
================================================================================
SRGAN Pipeline Setup Verification
================================================================================

1. System Requirements
--------------------------------------------------------------------------------
  ✓ Docker installed
  ✓ Docker Compose v2 installed
  ✓ Python 3 installed
  ✓ Python package 'flask' installed
  ✓ Python package 'requests' installed

✓ Verification passed
```

**If checks fail:**
- Shows what's missing
- Continues anyway (with warning)
- User can fix and re-run

### 2. Integrated Model Setup (Step 3)

**Checks for model and prompts user:**

```bash
Step 3: Setting up AI model (optional)...
========================================================================
AI model not found.

The AI model is optional - the pipeline works with ffmpeg upscaling by default.
Model is only needed if you set SRGAN_ENABLE=1 in docker-compose.yml.

Download AI model now? (y/N)
```

**Options:**
- **Yes**: Runs `setup_model.sh` interactively
- **No**: Skips model, shows how to download later
- **Already exists**: Just confirms it's ready

**Handles:**
- Existing `.pth` file → ✓ Ready
- Existing `.pth.tar` file → Auto-renames to `.pth`
- No model → Prompts user to download
- Download option or manual instructions

### 3. Progress Indicators

**Clear step-by-step output:**

```
========================================================================
Real-Time HDR SRGAN Pipeline - Automated Installation
========================================================================

Step 1: Verifying system prerequisites...
Step 2: Building Jellyfin plugin (if available)...
Step 3: Setting up AI model (optional)...
Step 4: Building Docker images...
Step 5: Starting srgan-upscaler container...
Step 6: Running GPU detection...
Step 7: Cleaning up old upscaled files...
Step 8: Installing watchdog systemd service...
```

**Color-coded output:**
- 🔵 Blue: Step headers
- 🟢 Green: Success messages (✓)
- 🟡 Yellow: Warnings (⚠)
- 🔴 Red: Errors (✗)

### 4. Completion Summary

**Shows what was installed:**

```
========================================================================
Installation Complete!
========================================================================

What was installed:
  ✓ Docker container (srgan-upscaler)
  ✓ Watchdog systemd service (auto-starts on boot)
  ✓ Jellyfin plugin
  ✓ AI model (optional)

Service Status:
  Watchdog: running ✓
  Container: running ✓

Next Steps:
  1. Configure Jellyfin webhook:
     See: /path/to/WEBHOOK_SETUP.md

  2. Test the webhook:
     python3 /path/to/scripts/test_webhook.py

  3. Check service status:
     /path/to/scripts/manage_watchdog.sh status

  4. View logs:
     /path/to/scripts/manage_watchdog.sh logs

Documentation:
  Getting Started: /path/to/GETTING_STARTED.md
  Webhook Setup:   /path/to/WEBHOOK_SETUP.md
  Service Mgmt:    /path/to/SYSTEMD_SERVICE.md
  Troubleshoot:    /path/to/TROUBLESHOOTING.md

Quick health check:
  Webhook: responding ✓
```

### 5. Better Error Handling

**Exits gracefully on critical errors:**

```bash
# Missing Docker
✗ Docker is not installed or not in PATH.
Please install Docker first: https://docs.docker.com/engine/install/

# Systemd service fails
✗ Watchdog service installation failed
  You can try installing manually:
  sudo ./scripts/install_systemd_watchdog.sh
```

**Continues on non-critical errors:**
- GPU detection failure → Warning, continues
- Jellyfin not found → Skips plugin, continues
- Cleanup fails → Warning, continues

## Installation Steps Breakdown

| Step | What It Does | Critical | Can Skip |
|------|-------------|----------|----------|
| **1. Verify Prerequisites** | Runs verify_setup.py | No | Continues with warning |
| **2. Build Plugin** | Builds Jellyfin plugin if detected | No | Auto-skips if no Jellyfin |
| **3. Setup Model** | Prompts for model download | No | User can skip |
| **4. Build Images** | Builds Docker container | Yes | Exits on failure |
| **5. Start Container** | Starts srgan-upscaler | Yes | Exits on failure |
| **6. GPU Detection** | Tests GPU (if RUN_GPU_DETECTION=1) | No | Optional flag |
| **7. Cleanup** | Cleans old files (if RUN_CLEANUP=1) | No | Optional flag |
| **8. Install Service** | Installs systemd service | Yes | Exits on failure |

## Usage

### Basic Installation

```bash
./scripts/install_all.sh
```

### With Options

```bash
# Skip GPU detection
RUN_GPU_DETECTION=0 ./scripts/install_all.sh

# Enable cleanup
RUN_CLEANUP=1 ./scripts/install_all.sh

# Custom Jellyfin paths
JELLYFIN_LIB_DIR=/usr/share/jellyfin/bin \
JELLYFIN_PLUGIN_DIR=/var/lib/jellyfin/plugins/RealTimeHDRSRGAN \
./scripts/install_all.sh

# Combine options
RUN_GPU_DETECTION=1 RUN_CLEANUP=1 ./scripts/install_all.sh
```

## Documentation Updates

All documentation updated to reflect integrated installation:

### README.md
- Quick start now mentions automatic verification
- Explains what installer does automatically
- Notes that verify_setup/setup_model are run by installer

### GETTING_STARTED.md
- Quick start section updated
- Manual steps note that verification is automatic
- Model setup notes it's prompted during install

### scripts/README.md
- Scripts marked as "AUTO-RUN" or "AUTO-PROMPT"
- First-time setup shows automated installer first
- Manual setup moved to secondary option

## Benefits Summary

### For Users

✅ **One command does everything**
- No need to remember multiple steps
- Prerequisites checked automatically
- Model setup guided and optional
- Clear next steps provided

✅ **Better user experience**
- Progress indicators show what's happening
- Color-coded output easy to read
- Helpful error messages
- Comprehensive completion summary

✅ **Less chance of mistakes**
- Verification ensures prerequisites met
- Model setup prompted (not forgotten)
- Service installed and started
- Health check confirms it's working

### For Maintainers

✅ **Fewer support requests**
- Users less likely to skip steps
- Prerequisites verified upfront
- Clear instructions after install
- Better error messages

✅ **Easier onboarding**
- New users get working system quickly
- Less documentation to read initially
- Automated setup reduces errors
- Next steps clearly shown

## Migration

### Existing Users

If you previously installed manually:

```bash
# Re-run installer to get benefits
./scripts/install_all.sh

# It will detect existing installations:
# - Model: "✓ Model file already exists"
# - Plugin: "Building plugin..." (updates it)
# - Service: Reinstalls/restarts service
# - Container: Rebuilds and restarts
```

Safe to re-run - existing configurations preserved.

### New Users

Just run:
```bash
./scripts/install_all.sh
```

That's it!

## Comparison

| Feature | Before | After |
|---------|--------|-------|
| **Commands needed** | 5-6 separate | 1 command |
| **Verification** | Manual | Automatic |
| **Model setup** | Manual | Prompted |
| **Progress feedback** | Minimal | Detailed |
| **Error handling** | Generic | Specific |
| **Completion info** | None | Comprehensive |
| **Next steps** | Unclear | Clearly shown |
| **Success rate** | Variable | High |

## Example Session

**Complete installation flow:**

```bash
$ ./scripts/install_all.sh

========================================================================
Real-Time HDR SRGAN Pipeline - Automated Installation
========================================================================

Step 1: Verifying system prerequisites...
========================================================================
[... verification output ...]
✓ Verification passed

Step 2: Building Jellyfin plugin (if available)...
========================================================================
Found Jellyfin at: /usr/lib/jellyfin/bin
Building plugin...
✓ Plugin installed

Step 3: Setting up AI model (optional)...
========================================================================
AI model not found.

The AI model is optional - the pipeline works with ffmpeg upscaling by default.
Model is only needed if you set SRGAN_ENABLE=1 in docker-compose.yml.

Download AI model now? (y/N) y

Downloading model file...
✓ Download complete
✓ Model file ready

Step 4: Building Docker images...
========================================================================
[... docker build output ...]
✓ Docker images built

Step 5: Starting srgan-upscaler container...
========================================================================
✓ Container started

Step 6: Running GPU detection...
========================================================================
✓ GPU detection completed

Step 8: Installing watchdog systemd service...
========================================================================
[... systemd installation output ...]
✓ Watchdog service installed and started

========================================================================
Installation Complete!
========================================================================

What was installed:
  ✓ Docker container (srgan-upscaler)
  ✓ Watchdog systemd service (auto-starts on boot)
  ✓ Jellyfin plugin
  ✓ AI model (optional)

Service Status:
  Watchdog: running ✓
  Container: running ✓

Next Steps:
  1. Configure Jellyfin webhook:
     See: WEBHOOK_SETUP.md
  [... more instructions ...]

Quick health check:
  Webhook: responding ✓
```

**Total time: ~3-5 minutes** (including model download)

## Technical Details

### Script Structure

```bash
# 1. Colors and setup
RED='\033[0;31m'
GREEN='\033[0;32m'
[... color definitions ...]

# 2. Print header
echo "Automated Installation"

# 3. Step 1: Verification
python3 verify_setup.py

# 4. Step 2-8: Installation steps
[... each step with error handling ...]

# 5. Completion summary
echo "Installation Complete!"
[... show what was installed ...]
[... show next steps ...]
```

### Error Handling

- **Critical errors**: Exit immediately with message
- **Non-critical errors**: Show warning, continue
- **Missing components**: Show how to install
- **Failed steps**: Show manual command

### Idempotency

Safe to run multiple times:
- Skips existing components
- Updates/reinstalls services
- Rebuilds containers
- Preserves configurations

## Future Improvements

Potential enhancements:

1. **Interactive mode**: Ask about each component
2. **Dry-run mode**: Show what would be installed
3. **Uninstall mode**: Remove all components
4. **Update mode**: Update existing installation
5. **Log file**: Save installation log
6. **Resume**: Continue from failed step

## Summary

The enhanced `install_all.sh` provides:

✅ Fully automated installation
✅ Integrated prerequisite verification
✅ Interactive model setup
✅ Clear progress indicators
✅ Helpful error messages
✅ Comprehensive completion summary
✅ Next steps guidance

**Result**: Users get a working system with a single command! 🎉
