# Complete Loading Flow - From Click to Playback

## Overview

This document shows the **complete user experience** from clicking play to watching the upscaled video, with the enhanced loading indicator that stays visible until playback begins.

## Complete Timeline

```
USER ACTION                 SYSTEM STATE                    WHAT USER SEES
═══════════════════════════════════════════════════════════════════════════

[0ms] Click Play Button
                           ├─ Jellyfin initiates playback
                           ├─ JavaScript detects play event
                           └─ Shows loading indicator
                                                            ┌────────────┐
                                                            │ Loading    │
                                                            │ 4K...      │
                                                            │ 0%         │
                                                            └────────────┘

[100ms] 
                           ├─ Watchdog receives webhook
                           ├─ Adds job to queue
                           └─ Returns HLS URL
                                                            ┌────────────┐
                                                            │ Loading    │
                                                            │ 4K...      │
                                                            │ 0%         │
                                                            └────────────┘

[500ms]
                           ├─ SRGAN pipeline starts
                           ├─ FFmpeg begins upscaling
                           └─ First HLS segments generating
                                                            ┌────────────┐
                                                            │ Loading    │
                                                            │ 4K...      │
                                                            │ 0%         │
                                                            └────────────┘

[1s]
                           ├─ HLS playlist created
                           ├─ First segment available
                           └─ Video buffering
                                                            ┌────────────┐
                                                            │ Loading    │
                                                            │ 4K...      │
                                                            │ 0%         │
                                                            └────────────┘

[2s]
                           ├─ Progress API returns data
                           ├─ 5-10% complete
                           └─ Video still buffering
                                                            ┌────────────┐
                                                            │ Loading    │ ← STAYS
                                                            │ 4K...      │   VISIBLE
                                                            │ 0%         │
                                                            └────────────┘

[2.5s]
                           ├─ Enough segments buffered
                           ├─ Video ready to play
                           └─ First frame rendered
                                                            ┌────────────┐
                                                            │ Loading    │ ← STILL
                                                            │ 4K...      │   SHOWING
                                                            │ 0%         │
                                                            └────────────┘

[3s] VIDEO STARTS PLAYING! ✅
                           ├─ 'playing' event fires
                           ├─ clearLoadingState() called
                           └─ Progress overlay shows
                                                            ┌────────────┐
                                                            │ Upscaling  │ ← CLEARS
                                                            │ at 1.2x    │   NOW
                                                            │ ▓░░ 15%    │
                                                            └────────────┘

[5s] Continuous Updates
                           ├─ Poll every 2 seconds
                           ├─ Update progress bar
                           └─ Update speed & ETA
                                                            ┌────────────┐
                                                            │ Upscaling  │
                                                            │ at 1.2x    │
                                                            │ ▓▓░ 25%    │
                                                            └────────────┘

[10s+] Ongoing
                           └─ Continue until complete
                                                            ┌────────────┐
                                                            │ Upscaling  │
                                                            │ at 1.2x    │
                                                            │ ▓▓▓ 45%    │
                                                            └────────────┘
```

## Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER'S SCREEN OVER TIME                       │
└─────────────────────────────────────────────────────────────────┘

[0ms] Click Play
┌────────────────────────────────────┐
│ Video Player                       │
│                    ┌──────────────┐│
│                    │ 🎬 Loading   ││ ← APPEARS
│ [Black]            │ 4K...        ││   INSTANTLY
│                    │ ░░░░░░  0%   ││
│                    └──────────────┘│
│ ▶️ [Play] ━━━━━━━━○━━━━━━ [⚙️]    │
└────────────────────────────────────┘

[1s] Buffering
┌────────────────────────────────────┐
│ Video Player                       │
│                    ┌──────────────┐│
│                    │ 🎬 Loading   ││ ← STAYS
│ [Buffering...]     │ 4K...        ││   VISIBLE
│                    │ ░░░░░░  0%   ││
│                    └──────────────┘│
│ ⏸️ [Pause] ━━━━━━━━○━━━━━━ [⚙️]    │
└────────────────────────────────────┘

[2s] Still Buffering
┌────────────────────────────────────┐
│ Video Player                       │
│                    ┌──────────────┐│
│                    │ 🎬 Loading   ││ ← STILL
│ [Buffering...]     │ 4K...        ││   SHOWING
│                    │ ░░░░░░  0%   ││
│                    └──────────────┘│
│ ⏸️ [Pause] ━━━━━━━━○━━━━━━ [⚙️]    │
└────────────────────────────────────┘

[3s] VIDEO PLAYS! ✅
┌────────────────────────────────────┐
│ Video Player                       │
│                    ┌──────────────┐│
│                    │ 🎬 Upscaling ││ ← CLEARS
│ [Video playing!]   │ at 1.2x      ││   WHEN
│                    │ ▓░░░░  15%   ││   PLAYING
│                    └──────────────┘│
│ ⏸️ [Pause] ━━━━━━━━○━━━━━━ [⚙️]    │
└────────────────────────────────────┘

[5s] Progress Updates
┌────────────────────────────────────┐
│ Video Player                       │
│                    ┌──────────────┐│
│                    │ 🎬 Upscaling ││
│ [Video playing]    │ at 1.2x      ││
│                    │ ▓▓░░░  25%   ││
│                    │ ETA: 2m 30s  ││
│                    └──────────────┘│
│ ⏸️ [Pause] ━━━━━━━━━○━━━━━ [⚙️]    │
└────────────────────────────────────┘
```

## State Transitions

### JavaScript State Machine

```
                  ┌─────────────────┐
                  │   Page Loaded   │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │   Idle State    │
                  │                 │
                  │ isLoading=false │
                  │ videoPlaying=F  │
                  └────────┬────────┘
                           │
                  User clicks play
                           │
                           ▼
                  ┌─────────────────┐
                  │ Loading State   │◄──────┐
                  │                 │       │
                  │ isLoading=true  │       │
                  │ videoPlaying=F  │       │ Progress data
                  │                 │       │ (but no playback)
                  │ Show "Loading..." │       │
                  └────────┬────────┘       │
                           │                │
                   Video starts playing     │
                      ('playing' event)     │
                           │                │
                           ▼                │
                  ┌─────────────────┐      │
                  │  Playing State  │──────┘
                  │                 │
                  │ isLoading=false │
                  │ videoPlaying=T  │
                  │                 │
                  │ Show progress   │
                  └────────┬────────┘
                           │
                    Video ends/stops
                           │
                           ▼
                  ┌─────────────────┐
                  │   Idle State    │
                  └─────────────────┘
```

## Code Flow

### 1. User Clicks Play

```javascript
// Jellyfin triggers play event
JellyfinPlayer.play(mediaPath)
    ↓
onPlaybackStart(mediaPath)
    ↓
videoIsPlaying = false;       // Not playing yet
showLoadingState();           // Show "Loading..."
    ↓
startPolling(mediaPath);      // Start checking progress
```

### 2. System Processes

```javascript
// Watchdog receives webhook
POST /upscale-trigger
    ↓
Queue job → SRGAN pipeline
    ↓
FFmpeg generates HLS segments
    ↓
Progress API returns data
```

### 3. Progress Updates (But No Playback)

```javascript
// Every 2 seconds
pollProgress()
    ↓
updateProgress(data)
    ↓
if (isLoading && videoIsPlaying) {  // videoIsPlaying = false
    clearLoadingState();            // DON'T CLEAR YET
}
    ↓
// Update progress data silently
// Keep showing "Loading..."
```

### 4. Video Starts Playing

```javascript
// Browser fires event
videoElement.dispatchEvent('playing')
    ↓
onVideoPlaying()
    ↓
videoIsPlaying = true;        // NOW playing!
clearLoadingState();          // Clear "Loading..."
    ↓
// Next progress update shows details
```

## Event Sequence

```
Time | Browser Event    | JS Handler        | State Change
-----|------------------|-------------------|------------------
0ms  | (click)          | onPlaybackStart() | Show loading
     |                  |                   | videoPlaying=F
     |                  |                   |
100ms| loadstart        | (ignored)         | (no change)
     |                  |                   |
500ms| loadedmetadata   | (ignored)         | (no change)
     |                  |                   |
1s   | loadeddata       | (ignored)         | (no change)
     |                  |                   |
2s   | canplay          | (ignored)         | (no change)
     |                  |                   | Loading still visible!
     |                  |                   |
3s   | playing ✅       | onVideoPlaying()  | Clear loading
     |                  |                   | videoPlaying=T
     |                  |                   | Show progress
     |                  |                   |
3.5s | timeupdate       | (confirmation)    | (already cleared)
     |                  |                   |
5s   | timeupdate       | (poll progress)   | Update progress
     |                  |                   |
7s   | timeupdate       | (poll progress)   | Update progress
```

## Why 'playing' Event?

### Event Comparison

**`play` event:**
- ✅ Fires immediately when play() called
- ❌ Fires before video actually renders
- ❌ Not reliable for playback confirmation

**`canplay` event:**
- ✅ Fires when enough data buffered
- ❌ Fires before video actually starts
- ❌ Not reliable for playback confirmation

**`playing` event:** ⭐
- ✅ Fires when video actually starts rendering
- ✅ Reliable indicator of playback
- ✅ Perfect for clearing loading state

**`timeupdate` event:** (backup)
- ✅ Fires as video progresses
- ✅ Can confirm currentTime > 0
- ✅ Good fallback if 'playing' missed

## Real-World Scenarios

### Fast Network (< 1s buffer)

```
0ms:  Click → Loading shows
500ms: Video ready, starts playing → Loading clears
Result: Loading visible for 500ms ✅
```

### Normal Network (2-3s buffer)

```
0ms:  Click → Loading shows
2s:   Progress data arrives → Loading STAYS
3s:   Video starts playing → Loading clears
Result: Loading visible for 3s ✅
```

### Slow Network (5s+ buffer)

```
0ms:  Click → Loading shows
2s:   Progress data arrives → Loading STAYS
4s:   More progress → Loading STAYS
6s:   Video starts playing → Loading clears
Result: Loading visible for 6s ✅
```

### Already Upscaled (instant)

```
0ms:  Click → Loading shows
100ms: Video starts playing → Loading clears
Result: Loading visible for 100ms ✅
```

## User Benefits

### Continuous Feedback
```
OLD: [Loading] → [?????] → [Progress]
NEW: [Loading] ────────→ [Progress]
```

### Clear Status
- "Loading..." = Preparing
- Stays visible = Still working
- Clears = Playback started

### Professional Feel
Matches Netflix, YouTube, Disney+, etc.

### No Confusion
Users always know the system is working.

## Summary

**Complete flow:**
1. Click play → Loading appears (0ms)
2. System processes → Loading stays visible
3. Progress arrives → Loading STILL visible
4. Video plays → Loading clears, show progress

**Key feature:**
**Loading indicator stays on screen until video actually starts playing!**

**Result:**
- ✅ Continuous feedback
- ✅ No gaps
- ✅ Professional UX
- ✅ Clear communication

**Files:**
- `playback-progress-overlay.js` (532 lines)
- Complete documentation
- Test scripts included

**Ready to use!** 📺✨
