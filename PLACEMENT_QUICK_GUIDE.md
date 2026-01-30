# Loading Indicator Placement - Quick Guide

## Where Does It Appear?

The loading indicator appears **on the video playback screen** in one of these positions:

## Option 1: Top-Right Corner (Default)

```
┌────────────────────────────────────────────────┐
│               VIDEO SCREEN                     │
│                                   ┌──────────┐ │
│                                   │ Loading  │ │
│        [Video Playing]            │ 4K...    │ │
│                                   │ 0%       │ │
│                                   └──────────┘ │
│                                         ↑      │
│                                    TOP-RIGHT   │
│ ▶️ Controls                                    │
└────────────────────────────────────────────────┘
```

**Pros:**
- ✅ Subtle, doesn't block video
- ✅ Professional look
- ✅ Easy to ignore if desired

**Cons:**
- ⚠️ Might be missed if not looking for it

## Option 2: Centered (More Prominent)

```
┌────────────────────────────────────────────────┐
│                                                │
│          ┌────────────────────┐                │
│          │   Loading 4K...    │                │
│  [Video] │   ░░░░░░░░ 0%      │                │
│          │   [Preparing...]   │                │
│          └────────────────────┘                │
│                   ↑                            │
│              CENTERED                          │
│ ▶️ Controls                                    │
└────────────────────────────────────────────────┘
```

**Pros:**
- ✅ Impossible to miss
- ✅ Clear, immediate feedback
- ✅ Familiar (Netflix/YouTube style)

**Cons:**
- ⚠️ Blocks center of video
- ⚠️ More intrusive

## How to Choose

### Use Top-Right (Default) If:
- You want minimal distraction
- Professional, subtle look
- Users are tech-savvy

### Use Centered If:
- You want maximum visibility
- Need to ensure users see it
- Users might not know where to look

## Quick Setup

### Stay with Top-Right (Default)
```javascript
// Already configured! No changes needed.
// Loading indicator appears in top-right corner.
```

### Switch to Centered
```javascript
// In browser console or edit the JS file:
JellyfinUpscalingProgress.config.centerLoadingIndicator = true

// Or add to playback-progress-overlay.js:
const CONFIG = {
    centerLoadingIndicator: true  // ← Change to true
};
```

### Use Centered CSS Variant
```html
<!-- Instead of (or in addition to) default CSS -->
<link rel="stylesheet" href="/playback-progress-overlay.css">
<link rel="stylesheet" href="/playback-progress-overlay-centered.css">

<!-- The -centered.css overrides default positioning -->
```

## Installation

**For Top-Right (Default):**
```bash
cp jellyfin-plugin/playback-progress-overlay.css /path/to/jellyfin/web/
cp jellyfin-plugin/playback-progress-overlay.js /path/to/jellyfin/web/
```

**For Centered:**
```bash
cp jellyfin-plugin/playback-progress-overlay.css /path/to/jellyfin/web/
cp jellyfin-plugin/playback-progress-overlay-centered.css /path/to/jellyfin/web/
cp jellyfin-plugin/playback-progress-overlay.js /path/to/jellyfin/web/
```

Then in Jellyfin HTML:
```html
<link rel="stylesheet" href="/playback-progress-overlay.css">
<link rel="stylesheet" href="/playback-progress-overlay-centered.css">
<script src="/playback-progress-overlay.js"></script>
```

## Visual Confirmation

**When you click play on a video, you should see:**

**Top-Right:**
- Small box appears in top-right corner
- Shows "Preparing 4K upscaling..."
- Animated progress bar
- Floats above video

**Centered:**
- Larger box appears in center of screen
- Dims background slightly
- More prominent animations
- Impossible to miss

## Testing

```bash
# Copy files
cp jellyfin-plugin/playback-progress-overlay* /path/to/jellyfin/web/

# Refresh browser (hard refresh)
Ctrl+Shift+R

# Click play on any video
# Loading indicator should appear ON SCREEN immediately!
```

**What to look for:**
- [ ] Appears within 100ms of clicking play
- [ ] Shows on the video screen (not in a separate window)
- [ ] Says "Preparing 4K upscaling..."
- [ ] Has animated progress bar
- [ ] Clearly visible against video background

## Troubleshooting

### "I don't see the loading indicator!"

**Check:**
1. Are the CSS/JS files copied to Jellyfin?
   ```bash
   ls /path/to/jellyfin/web/playback-progress-overlay.*
   ```

2. Did you refresh the browser?
   ```
   Ctrl+Shift+R (hard refresh)
   ```

3. Is it behind the video?
   ```javascript
   // Check z-index in browser console:
   getComputedStyle(document.querySelector('.upscaling-progress-container')).zIndex
   // Should be: 10000 or higher
   ```

4. Is it hidden?
   ```javascript
   // Check if hidden
   document.querySelector('.upscaling-progress-container').classList.contains('hidden')
   // Should be: false when loading
   ```

### "It's too small!"

Edit CSS:
```css
.upscaling-progress-content {
    min-width: 450px !important;  /* Make wider */
    padding: 35px !important;      /* More padding */
    font-size: 18px !important;    /* Larger text */
}
```

### "It's in the wrong position!"

Use the centered CSS:
```html
<link rel="stylesheet" href="/playback-progress-overlay-centered.css">
```

Or edit position manually:
```css
.upscaling-progress-container {
    top: 50% !important;
    left: 50% !important;
    transform: translate(-50%, -50%) !important;
}
```

## Summary

**The loading indicator appears ON THE VIDEO PLAYBACK SCREEN.**

**Default:** Top-right corner (subtle)
- Good for most users
- Professional look
- Doesn't block content

**Optional:** Centered (prominent)
- Impossible to miss
- More visible
- Netflix/YouTube style

**Choose based on your preference!**

Both work perfectly - it's just a matter of visibility vs. subtlety. 📺✨
