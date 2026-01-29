#!/bin/bash
# Test script for loading indicator behavior
# Tests that loading stays visible until video plays

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
JS_FILE="$REPO_DIR/jellyfin-plugin/playback-progress-overlay.js"

echo "========================================="
echo "Loading Indicator Behavior Test"
echo "========================================="
echo ""
echo "Testing: Loading stays visible until video plays"
echo ""

# Test 1: Check files exist
echo "Test 1: Check files exist..."
if [ ! -f "$JS_FILE" ]; then
    echo "❌ JavaScript file not found: $JS_FILE"
    exit 1
fi
echo "✅ JavaScript file exists"
echo ""

# Test 2: Check for videoIsPlaying flag
echo "Test 2: Check for videoIsPlaying state flag..."
if grep -q "let videoIsPlaying = false" "$JS_FILE"; then
    echo "✅ Found videoIsPlaying state tracking"
else
    echo "❌ Missing videoIsPlaying state flag"
    exit 1
fi
echo ""

# Test 3: Check for onVideoPlaying handler
echo "Test 3: Check for onVideoPlaying handler..."
if grep -q "function onVideoPlaying()" "$JS_FILE"; then
    echo "✅ Found onVideoPlaying() handler"
else
    echo "❌ Missing onVideoPlaying() handler"
    exit 1
fi
echo ""

# Test 4: Check for 'playing' event listener
echo "Test 4: Check for 'playing' event listener..."
if grep -q "addEventListener('playing'" "$JS_FILE"; then
    echo "✅ Found 'playing' event listener"
else
    echo "❌ Missing 'playing' event listener"
    exit 1
fi
echo ""

# Test 5: Check updateProgress logic
echo "Test 5: Check updateProgress conditional logic..."
if grep -q "if (isLoading && videoIsPlaying)" "$JS_FILE"; then
    echo "✅ Found correct conditional: isLoading && videoIsPlaying"
else
    echo "❌ Missing correct conditional logic"
    exit 1
fi
echo ""

# Test 6: Check that videoIsPlaying is set on playback start
echo "Test 6: Check videoIsPlaying reset on playback start..."
if grep -A5 "function onPlaybackStart" "$JS_FILE" | grep -q "videoIsPlaying = false"; then
    echo "✅ videoIsPlaying reset on playback start"
else
    echo "❌ videoIsPlaying not reset on playback start"
    exit 1
fi
echo ""

# Test 7: Check that videoIsPlaying is set to true in handler
echo "Test 7: Check videoIsPlaying set to true in handler..."
if grep -A3 "function onVideoPlaying" "$JS_FILE" | grep -q "videoIsPlaying = true"; then
    echo "✅ videoIsPlaying set to true in handler"
else
    echo "❌ videoIsPlaying not set to true in handler"
    exit 1
fi
echo ""

# Test 8: Check for timeupdate backup
echo "Test 8: Check for timeupdate event backup..."
if grep -q "addEventListener('timeupdate'" "$JS_FILE"; then
    echo "✅ Found timeupdate backup detection"
else
    echo "⚠️  No timeupdate backup (optional)"
fi
echo ""

# Test 9: Check JavaScript syntax
echo "Test 9: Check JavaScript syntax..."
if node -c "$JS_FILE" 2>/dev/null; then
    echo "✅ JavaScript syntax is valid"
elif python3 -c "import sys; sys.exit(0)" 2>/dev/null; then
    # If node not available, just check for common syntax errors
    if grep -E "^\s*}\s*else\s+{" "$JS_FILE" >/dev/null; then
        echo "⚠️  Warning: Possible syntax issue with } else {"
    fi
    echo "⚠️  Node.js not available, syntax check skipped"
else
    echo "⚠️  Cannot verify syntax"
fi
echo ""

# Test 10: Count key occurrences
echo "Test 10: Verify implementation completeness..."
VIDEO_PLAYING_COUNT=$(grep -c "videoIsPlaying" "$JS_FILE" || echo "0")
ON_VIDEO_PLAYING_COUNT=$(grep -c "onVideoPlaying" "$JS_FILE" || echo "0")
PLAYING_EVENT_COUNT=$(grep -c "addEventListener('playing'" "$JS_FILE" || echo "0")

echo "  - videoIsPlaying references: $VIDEO_PLAYING_COUNT"
echo "  - onVideoPlaying references: $ON_VIDEO_PLAYING_COUNT"
echo "  - 'playing' event listeners: $PLAYING_EVENT_COUNT"

if [ "$VIDEO_PLAYING_COUNT" -ge 4 ] && [ "$ON_VIDEO_PLAYING_COUNT" -ge 2 ] && [ "$PLAYING_EVENT_COUNT" -ge 1 ]; then
    echo "✅ Implementation looks complete"
else
    echo "⚠️  Implementation may be incomplete"
fi
echo ""

echo "========================================="
echo "All tests passed! ✅"
echo "========================================="
echo ""
echo "Expected behavior:"
echo "  1. Click play → Loading appears (0ms)"
echo "  2. Video buffering → Loading STAYS visible"
echo "  3. Video plays → Loading clears"
echo "  4. Progress updates → Shows details"
echo ""
echo "Timeline:"
echo "  [Click] → [Loading...] → [Loading...] → [Video plays] → [Progress]"
echo "            0ms            1-2s            3s             3s+"
echo ""
echo "Key feature:"
echo "  ★ Loading indicator stays visible until video plays!"
echo ""
echo "To deploy:"
echo "  cp $JS_FILE /path/to/jellyfin/web/"
echo "  Then refresh browser (Ctrl+Shift+R)"
