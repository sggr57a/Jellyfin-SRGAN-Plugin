# Theme Integration Guide

## Overview

The loading indicator and progress overlay now **automatically adapts to Jellyfin's current theme**, seamlessly blending with the rest of the interface.

## What Changed

### Before
```css
/* Hardcoded colors */
background: rgba(30, 30, 30, 0.98);
color: #fff;
border: 1px solid rgba(255, 255, 255, 0.1);
```

### After
```css
/* Uses Jellyfin's theme variables */
background: var(--card-background, rgba(30, 30, 30, 0.98));
color: var(--primary-text-color, #fff);
border: 1px solid var(--divider-color, rgba(255, 255, 255, 0.1));
```

## Jellyfin CSS Variables Used

The overlay now uses these Jellyfin theme variables:

### Colors
| Variable | Usage | Fallback |
|----------|-------|----------|
| `--accent-color` | Progress bar, borders, buttons | `#00a4dc` |
| `--primary-text-color` | Main text | `#fff` |
| `--secondary-text-color` | Labels, muted text | `rgba(255,255,255,0.6)` |
| `--success-color` | Complete status | `#4caf50` |
| `--warning-color` | Finalizing status | `#ffa500` |

### Backgrounds
| Variable | Usage | Fallback |
|----------|-------|----------|
| `--card-background` | Overlay background | `rgba(30,30,30,0.98)` |
| `--detail-background` | Details section | `rgba(255,255,255,0.05)` |
| `--progress-background` | Progress bar track | `rgba(255,255,255,0.1)` |

### Layout
| Variable | Usage | Fallback |
|----------|-------|----------|
| `--rounding` | Border radius | `12px` |
| `--rounding-small` | Button radius | `8px` |
| `--font-family` | Typography | System fonts |

### Shadows
| Variable | Usage | Fallback |
|----------|-------|----------|
| `--card-shadow` | Elevation | `0 10px 40px rgba(0,0,0,0.5)` |
| `--accent-shadow` | Button hover | `rgba(0,164,220,0.4)` |

## Theme Support

### Dark Theme
```
┌────────────────────────────────────┐
│ Dark Background                    │
│                    ┌──────────────┐│
│                    │ Dark Card    ││
│ [Video]            │ White Text   ││
│                    │ Blue Accent  ││
│                    └──────────────┘│
└────────────────────────────────────┘
```

Automatically uses:
- Dark card backgrounds
- Light text colors
- High contrast borders
- Bright accent colors

### Light Theme
```
┌────────────────────────────────────┐
│ Light Background                   │
│                    ┌──────────────┐│
│                    │ Light Card   ││
│ [Video]            │ Dark Text    ││
│                    │ Blue Accent  ││
│                    └──────────────┘│
└────────────────────────────────────┘
```

Automatically uses:
- Light card backgrounds
- Dark text colors
- Subtle borders
- Vibrant accent colors

### Custom Themes

**If you create a custom Jellyfin theme**, the overlay will automatically adapt!

Example custom theme:
```css
:root {
    --accent-color: #ff6b35;        /* Orange accent */
    --card-background: #2a2a2a;     /* Custom dark gray */
    --primary-text-color: #e0e0e0;  /* Light gray text */
}
```

The overlay will use these colors:

```
┌────────────────────────────────────┐
│                    ┌──────────────┐│
│                    │ #2a2a2a BG   ││
│ [Video]            │ #e0e0e0 Text ││
│                    │ #ff6b35 Bar  ││ ← Your custom colors!
│                    └──────────────┘│
└────────────────────────────────────┘
```

## Visual Examples

### Default Jellyfin Dark Theme

```
┌─────────────────────────────────────┐
│ 🎬 4K Upscaling               × │
├─────────────────────────────────────┤
│ Upscaling at 1.2x speed             │
│ ▓▓▓▓▓▓░░░░░ 55%                     │
│                                     │
│ Speed: 1.2x    ETA: 2m              │
│ Segments: 45                        │
└─────────────────────────────────────┘
  ↑ Dark background, blue accent
```

### Jellyfin Light Theme

```
┌─────────────────────────────────────┐
│ 🎬 4K Upscaling               × │
├─────────────────────────────────────┤
│ Upscaling at 1.2x speed             │
│ ▓▓▓▓▓▓░░░░░ 55%                     │
│                                     │
│ Speed: 1.2x    ETA: 2m              │
│ Segments: 45                        │
└─────────────────────────────────────┘
  ↑ Light background, dark text
```

### Purple Custom Theme

```
┌─────────────────────────────────────┐
│ 🎬 4K Upscaling               × │
├─────────────────────────────────────┤
│ Upscaling at 1.2x speed             │
│ ▓▓▓▓▓▓░░░░░ 55%                     │
│                                     │
│ Speed: 1.2x    ETA: 2m              │
│ Segments: 45                        │
└─────────────────────────────────────┘
  ↑ Purple accent throughout
```

## How It Works

### Variable Cascade

The CSS uses a fallback system:

```css
/* Example: Button color */
background: var(
    --accent-color,              /* 1. Try Jellyfin's accent */
    var(
        --theme-primary-color,   /* 2. Try theme primary */
        #00a4dc                  /* 3. Use default blue */
    )
);
```

This ensures:
1. ✅ Works with Jellyfin's theme system
2. ✅ Falls back gracefully if variables missing
3. ✅ Never breaks even in old Jellyfin versions

### Dynamic Adaptation

When you change themes in Jellyfin:
1. Jellyfin updates CSS variables
2. Overlay immediately reflects new colors
3. No page refresh needed!

```
User changes theme
       ↓
Jellyfin updates --accent-color
       ↓
Overlay progress bar updates
       ↓
Buttons update
       ↓
All colors match new theme ✅
```

## Browser Compatibility

### Supported
- ✅ Chrome/Edge (all versions with CSS variables)
- ✅ Firefox (all modern versions)
- ✅ Safari (all modern versions)
- ✅ Mobile browsers

### Fallbacks
- If CSS variables not supported → Uses fallback colors
- If Jellyfin variables not set → Uses sensible defaults
- Always displays, always works!

## Testing

### Test Theme Integration

1. **Open Jellyfin** in browser
2. **Go to Settings** → Display
3. **Change theme** (e.g., Dark → Light)
4. **Play a video** to trigger overlay
5. **Verify colors match** the new theme

### Expected Results

**Dark Theme:**
```
✅ Dark background
✅ Light text
✅ Blue/accent progress bar
✅ High contrast
```

**Light Theme:**
```
✅ Light background
✅ Dark text
✅ Blue/accent progress bar
✅ Subtle shadows
```

**Custom Theme:**
```
✅ Uses theme's accent color
✅ Uses theme's text colors
✅ Uses theme's backgrounds
✅ Matches theme's feel
```

## Customization

### Override Specific Colors

If you want to force specific colors (not recommended):

```css
/* Add to custom CSS */
.upscaling-progress-content {
    --accent-color: #ff6b35 !important;  /* Force orange */
    --card-background: #1a1a1a !important;  /* Force dark */
}
```

### Match Specific Jellyfin Theme

For a specific theme only:

```css
/* Only in dark theme */
[data-theme="dark"] .upscaling-progress-content {
    --accent-color: #00d4ff;  /* Brighter blue in dark */
}

/* Only in light theme */
[data-theme="light"] .upscaling-progress-content {
    --accent-color: #0080cc;  /* Darker blue in light */
}
```

### Adjust Opacity

Make it more/less transparent:

```css
.upscaling-progress-content {
    background: var(--card-background) !important;
    opacity: 0.95;  /* Slightly transparent */
}
```

## Accessibility

### High Contrast Mode

Automatically enhanced in high contrast:

```css
@media (prefers-contrast: high) {
    .upscaling-progress-content {
        border: 2px solid;  /* Thicker border */
    }

    .upscaling-progress-bar {
        border: 1px solid;  /* Outlined progress */
    }
}
```

### Reduced Motion

Respects motion preferences:

```css
@media (prefers-reduced-motion: reduce) {
    /* All animations disabled */
    .upscaling-progress-content {
        animation: none;
    }
}
```

## Troubleshooting

### Colors Don't Match Theme

**Problem:** Overlay uses default colors instead of theme colors

**Solutions:**

1. **Check Jellyfin version:**
   ```
   Settings → Dashboard → About
   Ensure version 10.8+ (CSS variable support)
   ```

2. **Verify theme is active:**
   ```
   Settings → Display → Theme
   Ensure theme is selected and applied
   ```

3. **Clear browser cache:**
   ```
   Ctrl+Shift+R (hard refresh)
   ```

4. **Check CSS file is loaded:**
   ```javascript
   // Browser console
   getComputedStyle(document.querySelector('.upscaling-progress-content'))
       .getPropertyValue('--accent-color')
   // Should show theme color
   ```

### Overlay Too Transparent/Dark

**Adjust opacity:**

```css
.upscaling-progress-content {
    background: var(--card-background) !important;
    backdrop-filter: blur(20px);  /* More blur */
}
```

### Accent Color Not Showing

**Force accent color:**

```css
.upscaling-progress-fill {
    background: var(--accent-color, #00a4dc) !important;
}
```

## Deployment

### Updated Files

**CSS:**
```
jellyfin-plugin/playback-progress-overlay.css (updated)
```

**Backup:**
```
jellyfin-plugin/playback-progress-overlay.css.backup (original)
```

**Themed version:**
```
jellyfin-plugin/playback-progress-overlay-themed.css (reference)
```

### Installation

```bash
# Copy updated CSS
cp jellyfin-plugin/playback-progress-overlay.css /path/to/jellyfin/web/

# Refresh browser
Ctrl+Shift+R
```

### Verification

1. Open Jellyfin
2. Click play on video
3. Check overlay matches theme colors
4. Change theme and verify colors update

## Summary

### What This Gives You

✅ **Automatic theme matching** - No configuration needed
✅ **Light/dark theme support** - Switches automatically
✅ **Custom theme support** - Works with any theme
✅ **Accessibility** - High contrast, reduced motion
✅ **Future-proof** - Adapts to new themes
✅ **Seamless integration** - Looks native to Jellyfin

### Before vs After

**Before:**
- Fixed colors (always dark)
- Didn't match light themes
- Stood out as "different"
- Required manual updates

**After:**
- Automatic theme colors
- Matches all themes
- Blends seamlessly
- Zero maintenance!

---

**The overlay now perfectly matches Jellyfin's theme, providing a seamless, integrated experience!** 🎨✨
