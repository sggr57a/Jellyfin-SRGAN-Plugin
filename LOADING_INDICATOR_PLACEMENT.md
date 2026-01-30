# Loading Indicator - On-Screen Placement Guide

## Where It Appears

The loading indicator appears as a **floating overlay on the video playback screen**, not hidden away. Here's exactly where users will see it:

## Visual Layout

### Full Screen View

```
┌────────────────────────────────────────────────────────────────┐
│                        VIDEO PLAYBACK AREA                      │
│                                                                 │
│                                                                 │
│                                                    ┌──────────┐ │
│                                                    │🎬 4K     │ │
│                                                    │Upscaling │ │
│         [Video playing here]                      │          │ │
│                                                    │Preparing │ │
│                                                    │4K...     │ │
│                                                    │░░░░ 0%   │ │
│                                                    └──────────┘ │
│                                                    ↑ TOP RIGHT  │
│                                                                 │
│ ▶️ [Play/Pause]  ━━━━━━━━━━━━━━━━━━━━━━○━━  [Settings]        │
└────────────────────────────────────────────────────────────────┘
```

**Default Position:** Top-right corner
- Visible but not intrusive
- Doesn't block video content
- Easy to see at a glance
- Can be moved with CSS

## Current Implementation

### Desktop View
```
Screen
├─ Video Player (full width)
│  ├─ Video content (center)
│  ├─ Controls (bottom)
│  └─ Loading Indicator (top-right) ← HERE!
│     ├─ Shows instantly
│     ├─ Floats above video
│     └─ Semi-transparent background
```

### Mobile View
```
Screen
├─ Video Player (full width)
│  ├─ Video content
│  ├─ Controls
│  └─ Loading Indicator (stretches across top) ← HERE!
│     ├─ Full width on mobile
│     └─ More prominent
```

## Alternative: Centered Full-Screen Loading

If you prefer a **more prominent, centered loading indicator** (like Netflix/YouTube), here's how:

### Centered Loading Overlay

```
┌────────────────────────────────────────────────────────────────┐
│                                                                 │
│                                                                 │
│                     ┌─────────────────────┐                    │
│                     │   🎬 4K Upscaling   │                    │
│                     │                     │                    │
│        [Video]      │ Preparing 4K...     │                    │
│                     │                     │                    │
│                     │ ░░░░░░░░░░░░░  0%   │                    │
│                     │                     │                    │
│                     │    [Loading...]     │                    │
│                     └─────────────────────┘                    │
│                              ↑ CENTERED                         │
│                                                                 │
│ ▶️ [Controls]                                                   │
└────────────────────────────────────────────────────────────────┘
```

## Implementation Options

### Option 1: Top-Right (Current - Subtle)

**When to use:**
- Want minimal distraction
- User can choose to look at it
- Jellyfin's default UI style

**Pros:**
- ✅ Doesn't block video
- ✅ Professional look
- ✅ Matches Jellyfin style

**Cons:**
- ⚠️ Might be missed if user isn't looking

### Option 2: Centered (More Prominent)

**When to use:**
- Want guaranteed visibility
- Netflix/YouTube style
- Loading is critical to show

**Pros:**
- ✅ Impossible to miss
- ✅ Clear feedback
- ✅ Familiar to users

**Cons:**
- ⚠️ Blocks video content
- ⚠️ More intrusive

### Option 3: Top-Center Banner

**When to use:**
- Balance between visibility and subtlety
- Banner-style notification

**Pros:**
- ✅ Very visible
- ✅ Doesn't block center content
- ✅ Easy to dismiss

**Cons:**
- ⚠️ Takes up screen space

## How to Change Position

### Move to Center

Edit `playback-progress-overlay.css`:

```css
/* Change from top-right to centered */
.upscaling-progress-container {
    position: fixed;
    top: 50%;           /* Center vertically */
    left: 50%;          /* Center horizontally */
    transform: translate(-50%, -50%);  /* Perfect center */
    right: auto;        /* Remove right positioning */
}

/* Make it larger for center position */
.upscaling-progress-content {
    min-width: 400px;
    padding: 30px;
    text-align: center;
}
```

### Move to Top-Center

```css
.upscaling-progress-container {
    position: fixed;
    top: 20px;          /* Distance from top */
    left: 50%;          /* Center horizontally */
    transform: translateX(-50%);  /* Center alignment */
    right: auto;
}

/* Make it banner-style */
.upscaling-progress-content {
    min-width: 500px;
    border-radius: 8px;
}
```

### Move to Bottom

```css
.upscaling-progress-container {
    position: fixed;
    bottom: 80px;       /* Above video controls */
    right: 20px;
    top: auto;
}
```

## Make It More Prominent

### Larger Size

```css
.upscaling-progress-content {
    min-width: 400px;   /* Wider (default: 320px) */
    padding: 25px;      /* More padding (default: 20px) */
    font-size: 16px;    /* Larger text (default: 14px) */
}

.upscaling-title {
    font-size: 22px;    /* Bigger title (default: 18px) */
}
```

### More Opaque Background

```css
.upscaling-progress-content {
    background: rgba(30, 30, 30, 1);  /* Fully opaque (default: 0.98) */
    box-shadow: 0 15px 50px rgba(0, 0, 0, 0.8);  /* Stronger shadow */
}
```

### Add Backdrop Blur (Overlay Behind It)

```css
/* Add semi-transparent backdrop */
.upscaling-progress-container::before {
    content: '';
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.3);  /* Dim the video */
    backdrop-filter: blur(2px);       /* Blur background */
    z-index: -1;
}
```

### Pulsing Border for Attention

```css
.upscaling-progress-content.loading-state {
    animation: pulse-border 2s infinite;
}

@keyframes pulse-border {
    0%, 100% {
        border-color: #00a4dc;
        box-shadow: 0 0 0 0 rgba(0, 164, 220, 0.7);
    }
    50% {
        border-color: #0080ff;
        box-shadow: 0 0 20px 5px rgba(0, 164, 220, 0.3);
    }
}
```

## Recommended: Hybrid Approach

**Best of both worlds:**

1. **Loading state** → Centered and prominent
2. **Progress updates** → Top-right and subtle

```javascript
function showLoadingState() {
    const overlay = createProgressOverlay();
    
    // Center it during loading
    overlay.style.top = '50%';
    overlay.style.left = '50%';
    overlay.style.transform = 'translate(-50%, -50%)';
    overlay.style.right = 'auto';
    
    // ... rest of loading state
}

function clearLoadingState() {
    const overlay = overlayElement;
    
    // Move to top-right for progress
    overlay.style.top = '20px';
    overlay.style.left = 'auto';
    overlay.style.transform = '';
    overlay.style.right = '20px';
    
    // ... rest of clear logic
}
```

This way:
- Loading is **impossible to miss** (centered)
- Progress is **subtle and non-intrusive** (top-right)

## Testing Visibility

### Check on Different Screens

**Desktop (1920x1080):**
```
Top-right at 20px, 20px
Should be clearly visible above video
```

**Laptop (1366x768):**
```
Same position
Might need to reduce size slightly
```

**Mobile (375x667):**
```
Responsive CSS makes it full-width
Spans across top of screen
Very visible
```

**TV/4K (3840x2160):**
```
Same position but may look small
Consider increasing size for large screens:

@media (min-width: 2560px) {
    .upscaling-progress-content {
        min-width: 500px;
        font-size: 18px;
    }
}
```

## Example: Netflix-Style Centered Loading

If you want it exactly like Netflix:

```css
/* Full-screen overlay */
.upscaling-progress-container {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);  /* Dim entire screen */
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 99999;
}

.upscaling-progress-content {
    background: rgba(30, 30, 30, 0.95);
    min-width: 400px;
    max-width: 500px;
    padding: 40px;
    text-align: center;
    border-radius: 16px;
}

/* Larger spinner */
.upscaling-icon {
    font-size: 48px;
    margin-bottom: 20px;
}

/* Larger text */
.status-text {
    font-size: 18px;
    margin-bottom: 30px;
}
```

## Quick Configuration

### For Maximum Visibility

Add to CSS:

```css
/* MAKE IT IMPOSSIBLE TO MISS */

/* Centered */
.upscaling-progress-container {
    top: 50% !important;
    left: 50% !important;
    right: auto !important;
    transform: translate(-50%, -50%) !important;
}

/* Larger */
.upscaling-progress-content {
    min-width: 450px !important;
    padding: 35px !important;
    font-size: 18px !important;
}

/* Dimmed background */
.upscaling-progress-container::before {
    content: '';
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: -1;
}

/* Pulsing animation */
.loading-state {
    animation: pulse-scale 2s infinite;
}

@keyframes pulse-scale {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.05); }
}
```

## Summary

**Current Implementation:**
- ✅ Top-right corner
- ✅ Visible on screen during video playback
- ✅ Floats above video content
- ✅ Semi-transparent, professional look

**Easy to customize:**
- Move to center for more prominence
- Make larger for better visibility
- Add backdrop dim for more attention
- Keep subtle for minimal distraction

**The indicator IS on screen, visible during playback!**

Just choose the visibility level that matches your preference:
- **Subtle** = Top-right (current)
- **Balanced** = Top-center banner
- **Prominent** = Centered overlay

**Want me to implement one of the more prominent versions?** Let me know! 📺✨
