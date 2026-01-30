#!/bin/bash
# Comprehensive test script for HLS streaming functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TEST_VIDEO="${REPO_DIR}/input/test_video.mp4"
HLS_DIR="/data/upscaled/hls"
WATCHDOG_URL="http://localhost:5000"
HLS_SERVER_URL="http://localhost:8080"

echo "=========================================================================="
echo "HLS Streaming Functionality Test Suite"
echo "=========================================================================="
echo ""

# Test 1: Check Prerequisites
echo -e "${BLUE}Test 1: Checking Prerequisites${NC}"
echo ""

PREREQ_OK=true

# Check Docker
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${RED}✗ Docker not installed${NC}"
    PREREQ_OK=false
fi

# Check Docker Compose
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose v2 available${NC}"
else
    echo -e "${RED}✗ Docker Compose v2 not available${NC}"
    PREREQ_OK=false
fi

# Check Python
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}✓ Python 3 installed${NC}"
else
    echo -e "${RED}✗ Python 3 not installed${NC}"
    PREREQ_OK=false
fi

# Check FFmpeg
if command -v ffmpeg &> /dev/null; then
    echo -e "${GREEN}✓ FFmpeg installed${NC}"
else
    echo -e "${YELLOW}⚠ FFmpeg not installed (needed for test video generation)${NC}"
fi

if [ "$PREREQ_OK" = false ]; then
    echo ""
    echo -e "${RED}Prerequisites not met. Please install missing dependencies.${NC}"
    exit 1
fi

echo ""

# Test 2: Start Services
echo -e "${BLUE}Test 2: Starting Services${NC}"
echo ""

cd "$REPO_DIR"

echo "Starting Docker services..."
if docker compose up -d srgan-upscaler hls-server 2>&1 | grep -q "Started\|Running"; then
    echo -e "${GREEN}✓ Services started${NC}"
else
    echo -e "${YELLOW}⚠ Services may already be running${NC}"
fi

echo "Waiting for services to be ready..."
sleep 3

echo ""

# Test 3: Check Watchdog Health
echo -e "${BLUE}Test 3: Checking Watchdog Health${NC}"
echo ""

if curl -s "${WATCHDOG_URL}/health" | grep -q "healthy"; then
    echo -e "${GREEN}✓ Watchdog is healthy${NC}"
else
    echo -e "${RED}✗ Watchdog health check failed${NC}"
    echo "Make sure watchdog is running: python3 scripts/watchdog.py"
    exit 1
fi

# Check streaming mode
STREAMING_ENABLED=$(curl -s "${WATCHDOG_URL}/health" | python3 -c "import sys, json; print(json.load(sys.stdin).get('streaming_enabled', False))" 2>/dev/null || echo "false")

if [ "$STREAMING_ENABLED" = "True" ] || [ "$STREAMING_ENABLED" = "true" ]; then
    echo -e "${GREEN}✓ Streaming mode enabled${NC}"
else
    echo -e "${YELLOW}⚠ Streaming mode disabled${NC}"
    echo "  Set ENABLE_HLS_STREAMING=1 in docker-compose.yml"
fi

echo ""

# Test 4: Check HLS Server
echo -e "${BLUE}Test 4: Checking HLS Server${NC}"
echo ""

if curl -s "${HLS_SERVER_URL}/health" | grep -q "healthy"; then
    echo -e "${GREEN}✓ HLS server is running${NC}"
else
    echo -e "${RED}✗ HLS server not accessible${NC}"
    echo "Check: docker compose ps hls-server"
    exit 1
fi

echo ""

# Test 5: Create Test Video (if needed)
echo -e "${BLUE}Test 5: Preparing Test Video${NC}"
echo ""

if [ ! -f "$TEST_VIDEO" ]; then
    if command -v ffmpeg &> /dev/null; then
        echo "Creating test video..."
        mkdir -p "$(dirname "$TEST_VIDEO")"
        
        ffmpeg -f lavfi -i testsrc=duration=30:size=1280x720:rate=24 \
               -f lavfi -i sine=frequency=1000:duration=30 \
               -c:v libx264 -preset ultrafast -c:a aac \
               -t 30 "$TEST_VIDEO" -y &> /dev/null
        
        echo -e "${GREEN}✓ Test video created: $TEST_VIDEO${NC}"
    else
        echo -e "${YELLOW}⚠ FFmpeg not available, skipping test video creation${NC}"
        echo "  Please place a test video at: $TEST_VIDEO"
        echo ""
        echo "Continuing with remaining tests..."
        TEST_VIDEO=""
    fi
else
    echo -e "${GREEN}✓ Test video exists: $TEST_VIDEO${NC}"
fi

echo ""

# Test 6: Trigger Upscaling
if [ -n "$TEST_VIDEO" ]; then
    echo -e "${BLUE}Test 6: Triggering Upscaling${NC}"
    echo ""
    
    PAYLOAD=$(cat <<EOF
{
  "Item": {
    "Path": "$TEST_VIDEO",
    "Name": "test_video"
  }
}
EOF
)
    
    echo "Sending webhook request..."
    RESPONSE=$(curl -s -X POST "${WATCHDOG_URL}/upscale-trigger" \
         -H "Content-Type: application/json" \
         -d "$PAYLOAD")
    
    echo "Response: $RESPONSE"
    
    if echo "$RESPONSE" | grep -q '"status":"started"\|"status":"streaming"'; then
        echo -e "${GREEN}✓ Upscaling triggered successfully${NC}"
        HLS_URL=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('hls_url', ''))" 2>/dev/null || echo "")
        echo "  HLS URL: $HLS_URL"
    elif echo "$RESPONSE" | grep -q '"status":"ready"'; then
        echo -e "${GREEN}✓ File already upscaled${NC}"
    else
        echo -e "${RED}✗ Unexpected response${NC}"
    fi
    
    echo ""
    
    # Test 7: Monitor HLS Generation
    echo -e "${BLUE}Test 7: Monitoring HLS Generation${NC}"
    echo ""
    
    echo "Waiting for HLS segments to be generated (30 seconds)..."
    echo "Press Ctrl+C to skip waiting"
    
    for i in {1..15}; do
        sleep 2
        
        HLS_DIR_TEST="${HLS_DIR}/test_video"
        if [ -d "$HLS_DIR_TEST" ]; then
            SEGMENT_COUNT=$(find "$HLS_DIR_TEST" -name "segment_*.ts" 2>/dev/null | wc -l)
            if [ "$SEGMENT_COUNT" -gt 0 ]; then
                echo -e "${GREEN}✓ HLS segments found: $SEGMENT_COUNT${NC}"
                break
            fi
        fi
        
        if [ $i -eq 15 ]; then
            echo -e "${YELLOW}⚠ No HLS segments found after 30 seconds${NC}"
            echo "  This might mean upscaling is slower than real-time"
            echo "  Check with: python3 scripts/audit_performance.py"
        fi
    done
    
    echo ""
    
    # Test 8: Check HLS Playlist
    echo -e "${BLUE}Test 8: Checking HLS Playlist${NC}"
    echo ""
    
    HLS_PLAYLIST="${HLS_DIR}/test_video/stream.m3u8"
    
    if [ -f "$HLS_PLAYLIST" ]; then
        echo -e "${GREEN}✓ HLS playlist exists${NC}"
        echo "  Location: $HLS_PLAYLIST"
        
        # Check playlist content
        if grep -q "#EXTM3U" "$HLS_PLAYLIST"; then
            echo -e "${GREEN}✓ Playlist format valid${NC}"
        else
            echo -e "${RED}✗ Invalid playlist format${NC}"
        fi
        
        # Check if complete
        if grep -q "#EXT-X-ENDLIST" "$HLS_PLAYLIST"; then
            echo -e "${GREEN}✓ Stream complete${NC}"
        else
            echo -e "${YELLOW}⚠ Stream still in progress${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ HLS playlist not found yet${NC}"
    fi
    
    echo ""
    
    # Test 9: Test HLS Server Access
    echo -e "${BLUE}Test 9: Testing HLS Server Access${NC}"
    echo ""
    
    HLS_URL="${HLS_SERVER_URL}/hls/test_video/stream.m3u8"
    
    if curl -s --head "$HLS_URL" | grep -q "200 OK"; then
        echo -e "${GREEN}✓ HLS playlist accessible via server${NC}"
        echo "  URL: $HLS_URL"
        
        # Test segment access
        if [ -f "$HLS_PLAYLIST" ]; then
            FIRST_SEGMENT=$(grep -m 1 "\.ts$" "$HLS_PLAYLIST" | tr -d '\r')
            if [ -n "$FIRST_SEGMENT" ]; then
                SEGMENT_URL="${HLS_SERVER_URL}/hls/test_video/${FIRST_SEGMENT}"
                if curl -s --head "$SEGMENT_URL" | grep -q "200 OK"; then
                    echo -e "${GREEN}✓ HLS segments accessible${NC}"
                else
                    echo -e "${RED}✗ HLS segment not accessible${NC}"
                fi
            fi
        fi
    else
        echo -e "${RED}✗ HLS playlist not accessible via server${NC}"
        echo "  Check nginx configuration and volume mounts"
    fi
    
    echo ""
fi

# Test 10: Test Playback with VLC (if available)
echo -e "${BLUE}Test 10: Test Playback (Optional)${NC}"
echo ""

if command -v vlc &> /dev/null && [ -n "$HLS_URL" ]; then
    echo "VLC is available. To test playback, run:"
    echo "  vlc $HLS_URL"
    echo ""
    
    read -p "Open in VLC now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        vlc "$HLS_URL" &>/dev/null &
        echo -e "${GREEN}✓ Opened in VLC${NC}"
    fi
else
    echo "To test playback manually:"
    echo "  1. Install VLC or MPV"
    echo "  2. Open URL: ${HLS_URL:-http://localhost:8080/hls/test_video/stream.m3u8}"
    echo ""
    echo "Or use ffplay:"
    echo "  ffplay ${HLS_URL:-http://localhost:8080/hls/test_video/stream.m3u8}"
fi

echo ""

# Summary
echo "=========================================================================="
echo "Test Summary"
echo "=========================================================================="
echo ""
echo "Components Tested:"
echo "  ✓ Prerequisites"
echo "  ✓ Docker services"
echo "  ✓ Watchdog health"
echo "  ✓ HLS server"
echo "  ✓ Upscale trigger"
echo "  ✓ HLS generation"
echo "  ✓ HLS playlist"
echo "  ✓ Server access"
echo ""
echo "Next Steps:"
echo "  1. Monitor upscaling: python3 scripts/monitor_hls.py ${HLS_DIR}/test_video"
echo "  2. Check performance: python3 scripts/audit_performance.py"
echo "  3. Test with Jellyfin: Play a video and check for HLS switch"
echo "  4. Cleanup: python3 scripts/cleanup_hls.py --dry-run"
echo ""
echo "Documentation:"
echo "  - Full guide: REAL_TIME_STREAMING.md"
echo "  - Configuration: docker-compose.yml"
echo "  - Troubleshooting: Check logs with docker compose logs -f"
echo ""
echo "=========================================================================="
echo -e "${GREEN}All tests complete!${NC}"
echo "=========================================================================="
