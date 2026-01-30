# Loading Indicator - Stays Until Playback Starts

## Enhanced Behavior

The loading indicator now stays visible **until the video actually starts playing**, providing continuous feedback during the entire startup delay.

## Timeline

### Previous Behavior (Before)
```
User clicks play
    ↓
[0ms]   Loading indicator appears
    ↓
[2s]    Upscaling data arrives → Loading indicator disappears
    ↓
[3s]    Video starts playing
    ↓
        ^ 1 second gap with no indicator! ^
```

### New Behavior (After)
```
User clicks play
    ↓
[0ms]   Loading indicator appears ✅
    ↓
        "Preparing 4K upscaling..."
    ↓
[2s]    Upscaling data arrives
        Loading indicator STAYS VISIBLE ✅
    ↓
        Still showing "Preparing 4K..."
    ↓
[3s]    Video starts playing
        Loading indicator clears
        Progress overlay shows details
    ↓
        ^ No gap! Continuous feedback! ^
```

## Visual Flow

### On Screen

```
┌────────────────────────────────────────────────┐
│ Click Play                                     │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│ Video Screen                  ┌──────────────┐ │
│                               │ Loading 4K.. │ │ ← APPEARS
│ [Black/Loading]               │ ░░░░░░  0%   │ │   IMMEDIATELY
│                               └──────────────┘ │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│ Video Screen                  ┌──────────────┐ │
│                               │ Loading 4K.. │ │ ← STAYS
│ [Still buffering]             │ ░░░░░░  0%   │ │   VISIBLE
│                               └──────────────┘ │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│ Video Screen                  ┌──────────────┐ │
│                               │ Upscaling at │ │ ← CLEARS WHEN
│ [First frame appears]         │ 1.2x         │ │   VIDEO PLAYS
│                               │ ▓▓░░░  15%   │ │
│                               └──────────────┘ │
└────────────────────────────────────────────────┘
```

## How It Works

### Event Detection

The system now listens for **actual playback events**:

```javascript
// Monitor video element
videoElement.addEventListener('playing', onVideoPlaying);

// Backup detection via timeupdate
videoElement.addEventListener('timeupdate', () => {
    if (currentTime > 0 && !videoIsPlaying) {
        onVideoPlaying();
    }
});
```

### Loading State Logic

```javascript
function updateProgress(data) {
    // Only clear loading if video is ACTUALLY playing
    if (isLoading && videoIsPlaying) {
        clearLoadingState();
    }
    
    // Update progress data
    // (but keep loading state if video hasn't started)
}
```

### State Tracking

```javascript
// When user clicks play
onPlaybackStart() {
    videoIsPlaying = false;  // Not playing yet
    showLoadingState();      // Show loading
}

// When video actually starts
onVideoPlaying() {
    videoIsPlaying = true;   // Now playing!
    clearLoadingState();     // Clear loading
}
```

## Benefits

### Continuous Feedback
```
Before: [Loading] → [Gap] → [Progress]
After:  [Loading] ──────────→ [Progress]
```

**No gaps!** User always sees feedback.

### Clear Communication

**User sees:**
1. Click play → "Preparing 4K upscaling..." (0ms)
2. Waiting → Still shows "Preparing..." (0-3s)
3. Video starts → Shows progress details (3s+)

**User knows:**
- System is working (not frozen)
- Video is being prepared
- Exactly when playback begins

### Better UX

**Old way:**
- Shows loading briefly
- Loading disappears before video plays
- Confusing gap where nothing happens
- Looks broken

**New way:**
- Shows loading immediately
- Stays visible entire time
- Only clears when video actually plays
- Smooth, professional transition

## Technical Details

### Playback Events Used

**Primary: `playing` event**
```javascript
videoElement.addEventListener('playing', () => {
    // Video has started playing
    // Data is being rendered
    // Safe to clear loading state
});
```

**Backup: `timeupdate` event**
```javascript
videoElement.addEventListener('timeupdate', () => {
    if (currentTime > 0) {
        // Video is definitely playing
        // (in case 'playing' event missed)
    }
});
```

### State Flags

```javascript
isLoading: false     // No loading indicator
videoIsPlaying: false // Video not started

↓ User clicks play ↓

isLoading: true      // Show loading
videoIsPlaying: false // Still waiting

↓ Upscaling starts (2s) ↓

isLoading: true      // Keep loading! ✅
videoIsPlaying: false // Still no playback

↓ Video plays (3s) ↓

isLoading: false     // Clear loading
videoIsPlaying: true // Playback confirmed
```

## Configuration

### Disable if Needed

If you want the old behavior (clear loading on progress data):

```javascript
// In playback-progress-overlay.js:
const CONFIG = {
    showLoadingImmediately: true,
    clearLoadingOnProgress: true,  // Add this
};

// In updateProgress():
if (isLoading && (videoIsPlaying || CONFIG.clearLoadingOnProgress)) {
    clearLoadingState();
}
```

### Adjust Timing

```javascript
const CONFIG = {
    // How long to wait before starting progress poll
    progressPollDelay: 2000,  // 2 seconds
    
    // Max time to show loading (force clear)
    maxLoadingTime: 10000,    // 10 seconds
};
```

## Example Scenarios

### Scenario 1: Fast Network
```
Time  | Loading | Video | Progress | User Sees
------|---------|-------|----------|------------------
0ms   | Show    | Wait  | None     | "Loading..."
500ms | Show    | Wait  | 0%       | "Loading..." ✅
1s    | Show    | Wait  | 5%       | "Loading..." ✅
1.5s  | Show    | Play! | 10%      | → Progress details
```

Loading stays visible for 1.5s until playback.

### Scenario 2: Slow Network
```
Time  | Loading | Video | Progress | User Sees
------|---------|-------|----------|------------------
0ms   | Show    | Wait  | None     | "Loading..."
2s    | Show    | Wait  | 0%       | "Loading..." ✅
4s    | Show    | Wait  | 15%      | "Loading..." ✅
5s    | Show    | Play! | 20%      | → Progress details
```

Loading stays visible for 5s until playback.

### Scenario 3: Already Upscaled
```
Time  | Loading | Video | Progress | User Sees
------|---------|-------|----------|------------------
0ms   | Show    | Wait  | Ready!   | "Loading..." ✅
200ms | Show    | Play! | 100%     | → "Complete!"
```

Loading shows briefly, then clears on playback.

## User Experience

### What Users Notice

**Before this change:**
> "I clicked play, saw 'Loading...' for a moment, 
>  then it disappeared but the video still hadn't started. 
>  I wasn't sure if it was working."

**After this change:**
> "I clicked play, saw 'Loading...' and it stayed 
>  there the whole time until the video started. 
>  Perfect!"

### Professional Polish

This is how major platforms handle it:

**Netflix:**
```
Click → Loading spinner → (stays until playback) → Video
```

**YouTube:**
```
Click → Buffering icon → (stays until playback) → Video
```

**Our implementation:**
```
Click → "Loading 4K..." → (stays until playback) → Progress
```

## Testing

### Verify Behavior

1. **Open browser console** (F12)
2. **Click play** on a video
3. **Watch console logs:**

```
[Progress] Playback started: /media/movie.mp4
[Progress] Loading state shown
[Progress] Fetching progress...
[Progress] Got progress: 0%
(Loading indicator still visible ✅)
[Progress] Got progress: 5%
(Loading indicator still visible ✅)
[Progress] Video playback confirmed
[Progress] Loading state cleared
(Now showing full progress overlay)
```

### Manual Test

```bash
# 1. Copy updated file
cp jellyfin-plugin/playback-progress-overlay.js /path/to/jellyfin/web/

# 2. Refresh browser (hard refresh)
Ctrl+Shift+R

# 3. Open console
F12

# 4. Click play on a video

# 5. Observe:
#    - Loading appears immediately ✅
#    - Loading stays until video plays ✅
#    - Progress shows after playback starts ✅
```

### Timing Test

```javascript
// Check how long loading was visible
let loadingShownAt = 0;
let playbackStartedAt = 0;

// Add to console:
document.querySelector('video').addEventListener('playing', () => {
    playbackStartedAt = Date.now();
    const duration = playbackStartedAt - loadingShownAt;
    console.log(`Loading visible for ${duration}ms`);
});
```

## Summary

### What Changed

**Code:**
- ✅ Added `videoIsPlaying` state flag
- ✅ Listen for `playing` event
- ✅ Only clear loading when video plays
- ✅ Keep loading during entire startup

**Behavior:**
- ✅ Loading shows immediately (0ms)
- ✅ Loading stays visible until playback
- ✅ No gaps in feedback
- ✅ Smooth transition to progress

**User Experience:**
- ✅ Continuous feedback
- ✅ No confusion
- ✅ Professional feel
- ✅ Clear communication

### Result

**The loading indicator now stays on screen from the moment you click play until the video actually starts playing.**

No more gaps. No more uncertainty. Just smooth, professional feedback. 📺✨
