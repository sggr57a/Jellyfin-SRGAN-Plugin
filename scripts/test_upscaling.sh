#!/bin/bash
#
# Test Upscaling Pipeline
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=========================================================================="
echo "Test Upscaling Pipeline"
echo "=========================================================================="
echo ""

# Check if test file path provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <path-to-video-file>"
    echo ""
    echo "Example:"
    echo "  $0 '/mnt/media/MOVIES/Back to the Future (1985)/Back to the Future (1985).mp4'"
    echo ""
    exit 1
fi

TEST_FILE="$1"

# Check if file exists
if [[ ! -f "$TEST_FILE" ]]; then
    echo -e "${RED}✗ File not found: $TEST_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Test file exists${NC}"
echo "  File: $TEST_FILE"
echo ""

# Rebuild container with latest code
echo -e "${BLUE}Step 1: Rebuilding Docker container with fixed code...${NC}"
cd "${REPO_DIR}"

if docker compose build srgan-upscaler; then
    echo -e "${GREEN}✓ Container rebuilt${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""

# Restart container
echo -e "${BLUE}Step 2: Restarting container...${NC}"
docker compose down srgan-upscaler
docker compose up -d srgan-upscaler

sleep 2

if docker ps | grep -q srgan-upscaler; then
    echo -e "${GREEN}✓ Container running${NC}"
else
    echo -e "${RED}✗ Container not running${NC}"
    exit 1
fi

echo ""

# Create test job
echo -e "${BLUE}Step 3: Creating test job in queue...${NC}"

BASENAME=$(basename "$TEST_FILE" | sed 's/\.[^.]*$//')
OUTPUT_FILE="${REPO_DIR}/upscaled/${BASENAME}.ts"
HLS_DIR="${REPO_DIR}/upscaled/hls/${BASENAME}"

# Clear old test outputs
rm -rf "$HLS_DIR"
rm -f "$OUTPUT_FILE"

# Create queue entry
QUEUE_FILE="${REPO_DIR}/cache/queue.jsonl"
mkdir -p "${REPO_DIR}/cache"

cat >> "$QUEUE_FILE" << EOF
{"input":"${TEST_FILE}","output":"${OUTPUT_FILE}","hls_dir":"${HLS_DIR}","streaming":true}
EOF

echo -e "${GREEN}✓ Job queued${NC}"
echo "  Input:  $TEST_FILE"
echo "  Output: $OUTPUT_FILE"
echo "  HLS:    $HLS_DIR"
echo ""

# Monitor processing
echo -e "${BLUE}Step 4: Monitoring processing (Ctrl+C to stop)...${NC}"
echo ""

# Show logs in real-time
echo -e "${CYAN}Container logs:${NC}"
docker logs -f srgan-upscaler 2>&1 &
LOGS_PID=$!

# Wait for HLS directory to be created
TIMEOUT=300  # 5 minutes
ELAPSED=0
while [[ $ELAPSED -lt $TIMEOUT ]]; do
    if [[ -d "$HLS_DIR" ]]; then
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Give it a few more seconds to generate some segments
sleep 10

# Kill log follow
kill $LOGS_PID 2>/dev/null || true

echo ""
echo "=========================================================================="
echo -e "${CYAN}Processing Status${NC}"
echo "=========================================================================="
echo ""

# Check HLS output
if [[ -d "$HLS_DIR" ]]; then
    echo -e "${GREEN}✓ HLS directory created${NC}"
    echo "  Location: $HLS_DIR"
    
    if [[ -f "${HLS_DIR}/stream.m3u8" ]]; then
        echo -e "${GREEN}✓ HLS playlist created${NC}"
        
        SEGMENT_COUNT=$(ls -1 "${HLS_DIR}"/segment_*.ts 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ HLS segments created: ${SEGMENT_COUNT}${NC}"
        
        # Show segment sizes
        echo ""
        echo "Recent segments:"
        ls -lh "${HLS_DIR}"/segment_*.ts 2>/dev/null | tail -5 | awk '{print "  " $9 " - " $5}'
    else
        echo -e "${YELLOW}⚠ HLS playlist not found yet${NC}"
    fi
else
    echo -e "${RED}✗ HLS directory not created${NC}"
    echo "Processing may have failed. Check logs:"
    echo "  docker logs srgan-upscaler"
fi

echo ""

# Check for errors in logs
echo "Checking for errors..."
ERROR_COUNT=$(docker logs srgan-upscaler 2>&1 | grep -i "error\|traceback\|failed" | wc -l)

if [[ $ERROR_COUNT -eq 0 ]]; then
    echo -e "${GREEN}✓ No errors found${NC}"
else
    echo -e "${YELLOW}⚠ Found $ERROR_COUNT error messages${NC}"
    echo "Last errors:"
    docker logs srgan-upscaler 2>&1 | grep -i "error\|traceback\|failed" | tail -5 | sed 's/^/  /'
fi

echo ""
echo "=========================================================================="
echo -e "${CYAN}Next Steps${NC}"
echo "=========================================================================="
echo ""

if [[ -f "${HLS_DIR}/stream.m3u8" ]]; then
    echo "✅ Upscaling is working!"
    echo ""
    echo "Test playback:"
    echo "  Open in VLC: http://localhost:8080/hls/${BASENAME}/stream.m3u8"
    echo "  Or: vlc ${HLS_DIR}/stream.m3u8"
    echo ""
    echo "Monitor progress:"
    echo "  watch -n 2 'ls -lh ${HLS_DIR}'"
    echo ""
    echo "View full logs:"
    echo "  docker logs -f srgan-upscaler"
else
    echo "⚠ Check logs for issues:"
    echo "  docker logs srgan-upscaler | less"
    echo ""
    echo "Verify file is accessible:"
    echo "  docker compose exec srgan-upscaler test -f '$TEST_FILE' && echo OK"
fi

echo ""
