# Progress Overlay - Automatic Installation

## Overview

The progress overlay CSS and JavaScript files are now **automatically installed** to Jellyfin's web directory (`/usr/share/jellyfin/web/`) during the standard installation process.

## What Gets Installed

### Files Copied

The installation script copies these files from `jellyfin-plugin/` to `/usr/share/jellyfin/web/`:

1. **`playback-progress-overlay.css`** (Required)
   - Theme-aware styling
   - 30+ CSS variables for Jellyfin integration
   - Light/dark/custom theme support
   - Accessibility features

2. **`playback-progress-overlay.js`** (Required)
   - Progress polling and display logic
   - Loading indicator (stays until playback)
   - Real-time updates every 2 seconds
   - Theme-aware event handling

3. **`playback-progress-overlay-centered.css`** (Optional)
   - Centered loading indicator variant
   - More prominent display option
   - Theme-aware glow effects

## Installation

### Automatic Installation

The overlay is automatically installed when you run:

```bash
./scripts/install_all.sh
```

This script (Step 2.5):
1. Locates Jellyfin web directory (default: `/usr/share/jellyfin/web/`)
2. Copies CSS and JavaScript files with `sudo`
3. Sets appropriate permissions
4. Confirms installation success

### Verify Installation

After installation, verify the files are in place:

```bash
./scripts/verify_overlay_install.sh
```

**Expected output:**
```
✅ Jellyfin web directory found: /usr/share/jellyfin/web
✅ playback-progress-overlay.css is installed
   Size: 14336 bytes
✅ playback-progress-overlay.js is installed
   Size: 17408 bytes
✅ playback-progress-overlay-centered.css is installed (optional)
   Size: 3840 bytes
✅ CSS file is readable
✅ JavaScript file is readable
✅ Jellyfin service is running
✅ All required files are installed!
```

## Using the Overlay

### Step 1: Restart Jellyfin

After installation, restart Jellyfin to enable file serving:

```bash
sudo systemctl restart jellyfin
```

### Step 2: Hard Refresh Browser

Clear browser cache to load new files:

**Windows/Linux:** `Ctrl+Shift+R`
**Mac:** `Cmd+Shift+R`

### Step 3: Test Playback

1. Open Jellyfin in browser
2. Click play on any video
3. Look for overlay in top-right corner
4. Verify loading indicator appears immediately
5. Check progress updates after playback starts

### What You'll See

**Immediately on play (< 100ms):**
```
┌────────────┐
│ 🎬 Loading │  ← Appears instantly
│ 4K...      │
│ ░░░░░ 0%   │
└────────────┘
```

**After video starts playing:**
```
┌────────────┐
│ 🎬 4K      │
│ Upscaling  │
├────────────┤
│ Upscaling  │
│ at 1.2x    │
│ ▓▓▓░░ 45%  │  ← Real-time progress
│            │
│ Speed: 1.2x│  ← Processing speed
│ ETA: 2m    │  ← Time remaining
└────────────┘
```

## Custom Installation Path

If Jellyfin is installed in a non-standard location, set the environment variable:

```bash
export JELLYFIN_WEB_DIR=/custom/path/to/jellyfin/web
./scripts/install_all.sh
```

Or install manually:

```bash
sudo cp jellyfin-plugin/playback-progress-overlay.css /custom/path/to/jellyfin/web/
sudo cp jellyfin-plugin/playback-progress-overlay.js /custom/path/to/jellyfin/web/
sudo cp jellyfin-plugin/playback-progress-overlay-centered.css /custom/path/to/jellyfin/web/
```

## Manual Installation

If you need to install manually (e.g., after updating files):

```bash
# Copy files
sudo cp jellyfin-plugin/playback-progress-overlay.css /usr/share/jellyfin/web/
sudo cp jellyfin-plugin/playback-progress-overlay.js /usr/share/jellyfin/web/

# Optional: Copy centered variant
sudo cp jellyfin-plugin/playback-progress-overlay-centered.css /usr/share/jellyfin/web/

# Restart Jellyfin
sudo systemctl restart jellyfin

# Verify
./scripts/verify_overlay_install.sh
```

## Troubleshooting

### Files Not Found After Installation

**Check installation log:**
```bash
# Re-run installation and look for Step 2.5 output
./scripts/install_all.sh
```

**Look for:**
```
Step 2.5: Installing Jellyfin progress overlay...
==========================================================================
Found Jellyfin web directory at: /usr/share/jellyfin/web
Installing progress overlay CSS...
✓ playback-progress-overlay.css installed
Installing progress overlay JavaScript...
✓ playback-progress-overlay.js installed
```

**If installation failed:**
```bash
# Check directory exists
ls -la /usr/share/jellyfin/web/

# Check permissions
ls -l /usr/share/jellyfin/web/playback-progress-overlay.*

# Try manual installation
sudo cp jellyfin-plugin/playback-progress-overlay.* /usr/share/jellyfin/web/
```

### Overlay Not Appearing in Browser

**1. Hard refresh browser:**
```
Ctrl+Shift+R (Windows/Linux)
Cmd+Shift+R (Mac)
```

**2. Check browser console (F12):**
Look for:
```javascript
[Progress] Upscaling Progress Overlay loaded
[Progress] Initializing upscaling progress overlay
```

**3. Verify files are accessible:**
```bash
curl -I http://localhost:8096/playback-progress-overlay.css
curl -I http://localhost:8096/playback-progress-overlay.js
```

Should return `200 OK`

**4. Check Jellyfin is serving files:**
```bash
# Check Jellyfin web directory
ls -la /usr/share/jellyfin/web/ | grep overlay

# Should show:
# -rw-r--r-- playback-progress-overlay.css
# -rw-r--r-- playback-progress-overlay.js
```

### Permission Errors

**If installation failed due to permissions:**

```bash
# Check current permissions
ls -l /usr/share/jellyfin/web/

# Fix ownership (Jellyfin user)
sudo chown jellyfin:jellyfin /usr/share/jellyfin/web/playback-progress-overlay.*

# Fix permissions (readable by all)
sudo chmod 644 /usr/share/jellyfin/web/playback-progress-overlay.*
```

### Custom Jellyfin Location

**If Jellyfin is not at `/usr/share/jellyfin/web/`:**

```bash
# Find Jellyfin web directory
find /usr -name "jellyfin" -type d 2>/dev/null
find /var -name "jellyfin" -type d 2>/dev/null
find /opt -name "jellyfin" -type d 2>/dev/null

# Common locations:
# - /usr/share/jellyfin/web
# - /var/lib/jellyfin/web
# - /opt/jellyfin/web
# - /usr/lib/jellyfin/web

# Set environment variable and re-run
export JELLYFIN_WEB_DIR=/actual/path/to/jellyfin/web
./scripts/install_all.sh
```

## Updating Overlay Files

If you update the overlay files (e.g., to fix bugs or add features):

```bash
# 1. Copy updated files
sudo cp jellyfin-plugin/playback-progress-overlay.css /usr/share/jellyfin/web/
sudo cp jellyfin-plugin/playback-progress-overlay.js /usr/share/jellyfin/web/

# 2. No need to restart Jellyfin (static files)

# 3. Hard refresh browser
Ctrl+Shift+R

# 4. Verify
./scripts/verify_overlay_install.sh
```

## Uninstallation

To remove the overlay files:

```bash
# Remove files
sudo rm /usr/share/jellyfin/web/playback-progress-overlay.css
sudo rm /usr/share/jellyfin/web/playback-progress-overlay.js
sudo rm /usr/share/jellyfin/web/playback-progress-overlay-centered.css

# Hard refresh browser
Ctrl+Shift+R
```

## Integration with Other Components

### Webhook Configuration

The overlay works with the webhook to display progress:

1. **Webhook** (`watchdog.py`) receives playback event
2. **Pipeline** starts upscaling
3. **Progress API** (`/progress/<filename>`) provides real-time data
4. **Overlay JavaScript** polls API every 2 seconds
5. **Overlay UI** displays progress on screen

**Configuration:** See `WEBHOOK_SETUP.md`

### HLS Streaming Integration

If HLS streaming is enabled, the overlay includes:

- Stream availability detection
- One-click stream switching
- HLS-specific progress info

**Configuration:** See `HLS_STREAMING_GUIDE.md`

### Theme Integration

The overlay automatically matches Jellyfin's theme:

- Dark theme → Dark overlay
- Light theme → Light overlay
- Custom theme → Adapts to your colors

**No configuration needed!** Uses CSS variables automatically.

**Details:** See `THEME_INTEGRATION_GUIDE.md`

## File Locations

### Source Files (Repository)
```
Real-Time-HDR-SRGAN-Pipeline/
└── jellyfin-plugin/
    ├── playback-progress-overlay.css
    ├── playback-progress-overlay.js
    ├── playback-progress-overlay-centered.css
    └── playback-progress-overlay.css.backup (original)
```

### Installed Files (Jellyfin)
```
/usr/share/jellyfin/web/
├── playback-progress-overlay.css
├── playback-progress-overlay.js
└── playback-progress-overlay-centered.css (optional)
```

### Installation Script
```
Real-Time-HDR-SRGAN-Pipeline/
└── scripts/
    ├── install_all.sh (copies files at Step 2.5)
    └── verify_overlay_install.sh (verification tool)
```

## Summary

### What Happens Automatically

When you run `./scripts/install_all.sh`:

1. ✅ Script detects Jellyfin web directory
2. ✅ Copies overlay CSS files
3. ✅ Copies overlay JavaScript file
4. ✅ Sets proper permissions
5. ✅ Confirms installation
6. ✅ Provides next steps

### What You Need to Do

After installation:

1. Restart Jellyfin: `sudo systemctl restart jellyfin`
2. Hard refresh browser: `Ctrl+Shift+R`
3. Test by playing a video
4. Look for overlay in top-right corner

### Verification

```bash
./scripts/verify_overlay_install.sh
```

Should show all green checkmarks ✅

---

**The progress overlay is now automatically installed - just run `install_all.sh` and it's ready to go!** 🎬✨
