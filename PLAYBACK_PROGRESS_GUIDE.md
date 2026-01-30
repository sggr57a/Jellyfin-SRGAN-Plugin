## Upscaling Progress in Playback Info

Complete guide for displaying real-time upscaling progress in Jellyfin's playback overlay.

## Overview

This feature adds a **beautiful, real-time progress overlay** to Jellyfin that shows:
- 📊 **Progress percentage** - How much of the video has been upscaled
- ⚡ **Processing speed** - Real-time multiplier (1.2x = 20% faster than playback)
- ⏱️ **ETA** - Estimated time until completion
- 🎬 **Segment count** - Number of HLS segments generated
- 🔄 **Status messages** - What's happening right now
- 🎯 **Switch button** - One-click to switch to upscaled stream

**What it looks like:**

```
┌─────────────────────────────────────┐
│ 🎬 4K Upscaling                  ×  │
├─────────────────────────────────────┤
│ Upscaling at 1.2x speed             │
│ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░  45%        │
│                                     │
│ Processing Speed: 1.2x              │
│ ETA: 2m 30s                         │
│ Segments: 45                        │
│                                     │
│ [Switch to Upscaled Stream]         │
└─────────────────────────────────────┘
```

## Quick Start

### 1. Files Included

**JavaScript:**
- `jellyfin-plugin/playback-progress-overlay.js` - Main logic

**CSS:**
- `jellyfin-plugin/playback-progress-overlay.css` - Styling

**API Endpoint:**
- `GET /progress/<filename>` - Returns real-time progress data

### 2. Installation

**Option A: Copy to Jellyfin Web Directory**

```bash
# Copy files to Jellyfin
cp jellyfin-plugin/playback-progress-overlay.js /path/to/jellyfin/web/
cp jellyfin-plugin/playback-progress-overlay.css /path/to/jellyfin/web/
```

**Option B: Inject into Jellyfin HTML**

Edit Jellyfin's `index.html` or custom theme:

```html
<!-- Add to <head> -->
<link rel="stylesheet" href="/playback-progress-overlay.css">

<!-- Add before </body> -->
<script src="/playback-progress-overlay.js"></script>
```

**Option C: Use Jellyfin's Custom CSS/JS Feature**

1. Open Jellyfin Dashboard
2. Go to **General → Custom CSS**
3. Paste the contents of `playback-progress-overlay.css`
4. Go to **General → Custom JavaScript**
5. Paste the contents of `playback-progress-overlay.js`

### 3. Verify Installation

**Test the API endpoint:**
```bash
# Should return JSON with progress data
curl 'http://localhost:5000/progress/Movie.mkv' | python3 -m json.tool
```

**Run test script:**
```bash
./scripts/test_progress_overlay.sh
```

**Test in browser:**
```javascript
// Open browser console (F12) while video is playing
window.JellyfinUpscalingProgress.show()
```

## Usage

### Keyboard Shortcuts

- **U** key - Toggle progress overlay
- **ESC** key - Close overlay

### Automatic Behavior

The overlay automatically:
- ✅ Shows "Loading..." immediately when video selected ⭐ NEW!
- ✅ Appears when upscaling starts
- ✅ Updates every 2 seconds
- ✅ Shows "Switch to Upscaled Stream" button when ready
- ✅ Hides automatically when complete (after 10 seconds)

**Loading State:**
When you click play on a video, you'll immediately see:
```
┌─────────────────────────────────────┐
│ 🎬 4K Upscaling                  ×  │
├─────────────────────────────────────┤
│ Preparing 4K upscaling...           │
│ ░░░░░░░░░░░░░░░░░░░░░░░░  0%       │
│ (animated sweep)                    │
└─────────────────────────────────────┘
```

This prevents the app from looking frozen during the initial 1-2 second delay before upscaling starts.

### Manual Control

**JavaScript API:**
```javascript
// Show overlay
window.JellyfinUpscalingProgress.show()

// Hide overlay
window.JellyfinUpscalingProgress.hide()

// Start monitoring specific file
window.JellyfinUpscalingProgress.start('/data/movies/Movie.mkv')

// Stop monitoring
window.JellyfinUpscalingProgress.stop()

// Configuration
window.JellyfinUpscalingProgress.config.pollInterval = 3000  // Check every 3 seconds
window.JellyfinUpscalingProgress.config.autoHide = false     // Don't auto-hide
```

## Features

### Real-Time Progress

**Progress Bar:**
- Smooth animated transitions
- Color-coded by status:
  - Blue = Processing
  - Orange = Finalizing
  - Green = Complete
- Shimmer effect during processing

**Status Messages:**
- "Starting upscale process..."
- "Upscaling at 1.2x speed" (good performance)
- "Upscaling (slower than real-time: 0.8x)" (performance warning)
- "Finalizing upscaled file..."
- "✓ Upscaling Complete!"

### Processing Speed Indicator

Shows real-time multiplier:
- **>= 1.0x** = Green (faster than or equal to real-time) ✅
- **< 1.0x** = Orange (slower than real-time) ⚠️

Example:
- `1.2x` = Processing 20% faster than playback
- `0.8x` = Processing 20% slower than playback

### ETA Calculation

Estimated time remaining based on:
- Current processing speed
- Total video duration
- Amount already processed

Formats:
- `45s` - Under 1 minute
- `2m 30s` - Under 1 hour
- `1h 15m` - Over 1 hour

### Switch to Upscaled Stream

Button appears when:
- HLS segments are available (>2 segments)
- Stream is ready for playback

Clicking the button:
- Switches video source to HLS stream
- Preserves current playback position
- Shows success notification
- Hides overlay

### Auto-Hide

Overlay automatically hides after:
- Upscaling completes
- 10 second delay (configurable)

Can be disabled:
```javascript
window.JellyfinUpscalingProgress.config.autoHide = false
```

## API Reference

### GET /progress/<filename>

Returns detailed progress information for an upscaling job.

**Parameters:**
- `filename` - Video filename (e.g., `Movie.mkv`)

**Response (Processing):**
```json
{
  "status": "processing",
  "progress": 45.3,
  "message": "Upscaling at 1.2x speed",
  "segments": 45,
  "current_duration": 270,
  "total_duration": 3600,
  "processing_rate": 1.23,
  "eta_seconds": 150,
  "hls_url": "http://localhost:8080/hls/Movie/stream.m3u8",
  "available": true
}
```

**Response (Complete):**
```json
{
  "status": "complete",
  "progress": 100,
  "message": "Upscaling complete",
  "file_size_mb": 15234.5,
  "available": true
}
```

**Response (Not Started):**
```json
{
  "status": "not_started",
  "progress": 0,
  "message": "Upscaling not started"
}
```

**Status Codes:**
- `200 OK` - Progress data available
- `404 Not Found` - Upscaling not started
- `500 Internal Server Error` - Server error

## Configuration

### JavaScript Config

Edit `playback-progress-overlay.js`:

```javascript
const CONFIG = {
    watchdogUrl: 'http://localhost:5000',  // Watchdog API URL
    pollInterval: 2000,                     // Check every 2 seconds
    showDelay: 1000,                        // Show after 1 second
    autoHide: true,                         // Auto-hide when complete
    hideDelay: 10000,                       // Hide after 10 seconds
    showLoadingImmediately: true            // Show "Loading..." immediately ⭐ NEW!
};
```

### CSS Customization

#### Change Position

```css
/* Top right (default) */
.upscaling-progress-container {
    top: 20px;
    right: 20px;
}

/* Top left */
.upscaling-progress-container {
    top: 20px;
    left: 20px;
    right: auto;
}

/* Bottom right */
.upscaling-progress-container {
    top: auto;
    bottom: 20px;
    right: 20px;
}
```

#### Change Colors

```css
/* Blue theme (default) */
.status-processing {
    border-left: 4px solid #00a4dc;
}

/* Purple theme */
.status-processing {
    border-left: 4px solid #9c27b0;
}

.upscaling-progress-fill {
    background: linear-gradient(90deg, #9c27b0 0%, #ba68c8 100%);
}
```

#### Change Size

```css
/* Compact */
.upscaling-progress-content {
    min-width: 280px;
    padding: 15px;
}

/* Large */
.upscaling-progress-content {
    min-width: 400px;
    padding: 25px;
    font-size: 16px;
}
```

## Testing

### Automated Tests

```bash
# Run test suite
./scripts/test_progress_overlay.sh

# Tests:
# 1. Watchdog API accessibility
# 2. Progress endpoint (not started)
# 3. Progress endpoint (with mock data)
# 4. File existence
# 5. JavaScript syntax
```

### Manual Testing

**Test API directly:**
```bash
# Create mock HLS directory
mkdir -p /data/upscaled/hls/TestMovie

# Create mock playlist
cat > /data/upscaled/hls/TestMovie/stream.m3u8 <<EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
segment_000.ts
segment_001.ts
EOF

# Create mock segments
touch /data/upscaled/hls/TestMovie/segment_{000,001,002}.ts

# Test API
curl 'http://localhost:5000/progress/TestMovie.mkv' | python3 -m json.tool
```

**Test in Jellyfin:**
1. Start playing a video
2. Trigger upscaling (webhook)
3. Press `U` key to show overlay
4. Verify progress updates
5. Click "Switch to Upscaled Stream" when available

### Browser Console Testing

```javascript
// Check if loaded
console.log(window.JellyfinUpscalingProgress)

// Show overlay
JellyfinUpscalingProgress.show()

// Start monitoring
JellyfinUpscalingProgress.start('/data/movies/Movie.mkv')

// Check config
console.log(JellyfinUpscalingProgress.config)

// Change update interval
JellyfinUpscalingProgress.config.pollInterval = 1000  // 1 second
```

## Troubleshooting

### Overlay Not Appearing

**Check:**
```bash
# 1. Verify files copied
ls /path/to/jellyfin/web/playback-progress-overlay.*

# 2. Check browser console for errors (F12)
# Look for: [Progress] Initializing upscaling progress overlay

# 3. Test API endpoint
curl 'http://localhost:5000/progress/Movie.mkv'

# 4. Verify watchdog running
curl 'http://localhost:5000/health'
```

**Fix:**
```bash
# Reload Jellyfin page
# Or hard refresh: Ctrl+Shift+R (Ctrl+Cmd+R on Mac)

# Check files are in correct location
# Jellyfin web root is usually:
# - /usr/share/jellyfin/web/
# - /var/lib/jellyfin/web/
# - C:\Program Files\Jellyfin\Server\jellyfin-web\
```

### Progress Not Updating

**Check:**
```bash
# 1. Verify upscaling started
curl 'http://localhost:5000/hls-status/Movie.mkv'

# 2. Check HLS directory exists
ls -la /data/upscaled/hls/Movie/

# 3. Watch logs
docker compose logs -f srgan-upscaler

# 4. Monitor API
watch -n 2 'curl -s http://localhost:5000/progress/Movie.mkv | python3 -m json.tool'
```

**Fix:**
```javascript
// In browser console:
// Stop and restart monitoring
JellyfinUpscalingProgress.stop()
JellyfinUpscalingProgress.start('/data/movies/Movie.mkv')
```

### Incorrect Progress Percentage

**Cause:** Video duration not detected

**Fix:**
```bash
# Check if ffprobe can read file
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 /data/movies/Movie.mkv

# Ensure queue file has correct input path
cat /app/cache/queue.jsonl
```

### Switch Button Not Appearing

**Check:**
```bash
# 1. Verify segments exist
ls -la /data/upscaled/hls/Movie/segment_*.ts

# 2. Need at least 3 segments
# Check segment count in API response
curl -s 'http://localhost:5000/progress/Movie.mkv' | grep segments
```

**Fix:**
```bash
# Wait for more segments to generate
# Or reduce HLS_SEGMENT_TIME in docker-compose.yml
```

### CORS Errors

**Error in console:**
```
Access to fetch at 'http://localhost:5000/progress/...' from origin 'http://jellyfin:8096' has been blocked by CORS
```

**Fix:**

Add CORS headers to watchdog.py (already included):
```python
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
    return response
```

Or use nginx reverse proxy.

## Advanced Features

### Custom Notifications

Override notification function:

```javascript
// Custom notification handler
const originalNotification = window.JellyfinHLS?.showNotification;

window.showUpscalingNotification = function(message, type) {
    // Your custom notification logic
    console.log(`${type}: ${message}`);

    // Or use Jellyfin's notification system
    if (window.Dashboard) {
        Dashboard.alert(message);
    }
};
```

### Progress Callbacks

```javascript
// Add callback when progress updates
const progressOverlay = document.querySelector('.upscaling-progress-container');

const observer = new MutationObserver(() => {
    const progress = document.querySelector('.upscaling-progress-text')?.textContent;
    console.log('Progress updated:', progress);

    // Your custom logic
    if (progress === '50%') {
        console.log('Halfway there!');
    }
});

if (progressOverlay) {
    observer.observe(progressOverlay, {
        childList: true,
        subtree: true
    });
}
```

### Analytics Integration

```javascript
// Track upscaling events
window.addEventListener('load', () => {
    const originalShow = window.JellyfinUpscalingProgress.show;
    const originalHide = window.JellyfinUpscalingProgress.hide;

    window.JellyfinUpscalingProgress.show = function() {
        // Analytics: User viewed progress overlay
        console.log('Analytics: Progress overlay shown');

        return originalShow.call(this);
    };

    window.JellyfinUpscalingProgress.hide = function() {
        // Analytics: User closed progress overlay
        console.log('Analytics: Progress overlay hidden');

        return originalHide.call(this);
    };
});
```

## Performance

### Resource Usage

**JavaScript:**
- File size: ~8 KB
- Memory: ~50 KB
- CPU: Minimal (polls every 2 seconds)

**CSS:**
- File size: ~6 KB
- No runtime performance impact

**Network:**
- ~100 bytes per API request
- 1 request every 2 seconds during upscaling
- Minimal bandwidth usage

### Optimization

**Reduce polling frequency:**
```javascript
// Check every 5 seconds instead of 2
JellyfinUpscalingProgress.config.pollInterval = 5000
```

**Disable animations on slow devices:**
```css
/* Add to CSS */
@media (max-width: 768px) {
    .upscaling-progress-fill::after,
    .status-processing .upscaling-icon {
        animation: none;
    }
}
```

## Accessibility

### Keyboard Navigation

- Fully keyboard accessible
- Tab through interactive elements
- ESC key to close
- U key to toggle

### Screen Readers

ARIA labels included:
```html
<div role="status" aria-live="polite" aria-label="Upscaling progress">
  <div>45% complete</div>
</div>
```

### High Contrast Mode

Automatic adjustments for:
- High contrast themes
- Dark mode
- Reduced motion preferences

## Mobile Support

Responsive design:
- Works on mobile browsers
- Touch-friendly buttons
- Adapts to small screens
- Swipe to dismiss (optional)

**Mobile-specific CSS:**
```css
@media (max-width: 768px) {
    .upscaling-progress-container {
        top: 10px;
        right: 10px;
        left: 10px;
    }
}
```

## Next Steps

1. **Test the overlay:**
   ```bash
   ./scripts/test_progress_overlay.sh
   ```

2. **Integrate with Jellyfin:**
   - Copy JS/CSS files
   - Inject into HTML or use custom CSS/JS
   - Test with real video

3. **Customize appearance:**
   - Edit CSS colors and positioning
   - Adjust polling interval
   - Configure auto-hide behavior

4. **Monitor in production:**
   ```bash
   # Watch API logs
   docker compose logs -f

   # Check browser console
   # Press F12, look for [Progress] messages
   ```

## Summary

✅ **Real-time progress overlay** - Beautiful, informative UI
✅ **Keyboard shortcuts** - U to toggle, ESC to close
✅ **Auto-updates** - Polls API every 2 seconds
✅ **One-click switching** - Button to switch to upscaled stream
✅ **Performance aware** - Shows processing speed and ETA
✅ **Auto-hide** - Disappears when done
✅ **Mobile-friendly** - Responsive design
✅ **Accessible** - Keyboard navigation, screen reader support

**Users will love seeing their upscaling progress in real-time!** 📊🎬
