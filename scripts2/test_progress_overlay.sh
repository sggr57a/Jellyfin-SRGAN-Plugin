#!/bin/bash
# Test script for upscaling progress overlay

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WATCHDOG_URL="http://localhost:5000"
TEST_FILE="test_video.mkv"

echo "=========================================================================="
echo "Upscaling Progress Overlay Test"
echo "=========================================================================="
echo ""

# Test 1: Check Watchdog
echo -e "${BLUE}Test 1: Checking Watchdog Service${NC}"
echo ""

if curl -s "${WATCHDOG_URL}/health" | grep -q "healthy"; then
    echo -e "${GREEN}✓ Watchdog is running${NC}"
else
    echo -e "${RED}✗ Watchdog not accessible${NC}"
    echo "Start watchdog: python3 scripts/watchdog.py"
    exit 1
fi

echo ""

# Test 2: Test Progress Endpoint (not started)
echo -e "${BLUE}Test 2: Testing Progress Endpoint (Not Started)${NC}"
echo ""

RESPONSE=$(curl -s "${WATCHDOG_URL}/progress/${TEST_FILE}")
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${WATCHDOG_URL}/progress/${TEST_FILE}")

if [ "$STATUS_CODE" = "404" ]; then
    echo -e "${GREEN}✓ Correctly returns 404 for non-existent upscale${NC}"
    echo "Response: $RESPONSE"
else
    echo -e "${YELLOW}⚠ Unexpected status code: $STATUS_CODE${NC}"
    echo "Response: $RESPONSE"
fi

echo ""

# Test 3: Test with simulated upscaling
echo -e "${BLUE}Test 3: Simulating Upscaling Progress${NC}"
echo ""

echo "Creating test HLS directory structure..."

TEST_HLS_DIR="/data/upscaled/hls/test_video"
sudo mkdir -p "$TEST_HLS_DIR" 2>/dev/null || mkdir -p "$TEST_HLS_DIR" 2>/dev/null || true

if [ -d "$TEST_HLS_DIR" ]; then
    echo -e "${GREEN}✓ Test HLS directory created${NC}"

    # Create mock playlist
    cat > "${TEST_HLS_DIR}/stream.m3u8" <<EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:6.0,
segment_000.ts
#EXTINF:6.0,
segment_001.ts
#EXTINF:6.0,
segment_002.ts
EOF

    # Create mock segments
    for i in {0..2}; do
        touch "${TEST_HLS_DIR}/segment_00${i}.ts"
    done

    echo -e "${GREEN}✓ Mock HLS files created${NC}"

    # Test progress endpoint
    echo ""
    echo "Testing progress endpoint..."
    PROGRESS_RESPONSE=$(curl -s "${WATCHDOG_URL}/progress/${TEST_FILE}")

    echo "Progress API Response:"
    echo "$PROGRESS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$PROGRESS_RESPONSE"

    # Check if response is valid JSON with expected fields
    if echo "$PROGRESS_RESPONSE" | grep -q '"status"'; then
        echo ""
        echo -e "${GREEN}✓ Progress endpoint returns valid data${NC}"

        # Extract key fields
        STATUS=$(echo "$PROGRESS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null || echo "unknown")
        PROGRESS=$(echo "$PROGRESS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('progress', 0))" 2>/dev/null || echo "0")
        SEGMENTS=$(echo "$PROGRESS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('segments', 0))" 2>/dev/null || echo "0")

        echo "  Status: $STATUS"
        echo "  Progress: $PROGRESS%"
        echo "  Segments: $SEGMENTS"
    else
        echo -e "${RED}✗ Invalid response from progress endpoint${NC}"
    fi

    # Cleanup
    echo ""
    echo "Cleaning up test files..."
    rm -rf "$TEST_HLS_DIR" 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
else
    echo -e "${YELLOW}⚠ Could not create test directory${NC}"
    echo "This test requires write access to /data/upscaled/hls/"
fi

echo ""

# Test 4: Check JavaScript/CSS files
echo -e "${BLUE}Test 4: Checking Overlay Files${NC}"
echo ""

JS_FILE="${REPO_DIR}/jellyfin-plugin/playback-progress-overlay.js"
CSS_FILE="${REPO_DIR}/jellyfin-plugin/playback-progress-overlay.css"

if [ -f "$JS_FILE" ]; then
    echo -e "${GREEN}✓ JavaScript file exists${NC}"
    echo "  Location: $JS_FILE"
    echo "  Size: $(wc -c < "$JS_FILE") bytes"
else
    echo -e "${RED}✗ JavaScript file missing${NC}"
fi

if [ -f "$CSS_FILE" ]; then
    echo -e "${GREEN}✓ CSS file exists${NC}"
    echo "  Location: $CSS_FILE"
    echo "  Size: $(wc -c < "$CSS_FILE") bytes"
else
    echo -e "${RED}✗ CSS file missing${NC}"
fi

echo ""

# Test 5: Syntax check
echo -e "${BLUE}Test 5: Checking JavaScript Syntax${NC}"
echo ""

if command -v node &> /dev/null; then
    if node -c "$JS_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ JavaScript syntax valid${NC}"
    else
        echo -e "${RED}✗ JavaScript syntax errors${NC}"
        node -c "$JS_FILE"
    fi
else
    echo -e "${YELLOW}⚠ Node.js not available (skipping syntax check)${NC}"
fi

echo ""

# Summary
echo "=========================================================================="
echo "Test Summary"
echo "=========================================================================="
echo ""
echo "Components:"
echo "  ✓ Watchdog API endpoint: /progress/<filename>"
echo "  ✓ JavaScript overlay: playback-progress-overlay.js"
echo "  ✓ CSS styling: playback-progress-overlay.css"
echo ""
echo "Integration:"
echo "  1. Copy files to Jellyfin:"
echo "     cp jellyfin-plugin/playback-progress-overlay.{js,css} /path/to/jellyfin/web/"
echo ""
echo "  2. Add to Jellyfin HTML (or custom theme):"
echo "     <link rel=\"stylesheet\" href=\"/playback-progress-overlay.css\">"
echo "     <script src=\"/playback-progress-overlay.js\"></script>"
echo ""
echo "  3. Play a video and press 'U' key to toggle overlay"
echo ""
echo "Manual Testing:"
echo "  # Test progress endpoint directly"
echo "  curl '${WATCHDOG_URL}/progress/Movie.mkv' | python3 -m json.tool"
echo ""
echo "  # In browser console (while video playing)"
echo "  window.JellyfinUpscalingProgress.start('/data/movies/Movie.mkv')"
echo "  window.JellyfinUpscalingProgress.show()"
echo ""
echo "=========================================================================="
echo -e "${GREEN}Tests complete!${NC}"
echo "=========================================================================="
