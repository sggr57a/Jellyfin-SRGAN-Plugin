#!/bin/bash
#
# Test Direct File Output (MKV/MP4)
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
echo "Test Direct File Output"
echo "=========================================================================="
echo ""

# Check if test file path provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <input-video-file> [output-format]"
    echo ""
    echo "Example:"
    echo "  $0 '/mnt/media/MOVIES/Movie.mp4' mkv"
    echo "  $0 '/mnt/media/MOVIES/Movie.mp4' mp4"
    echo ""
    echo "Output format: mkv (default) or mp4"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FORMAT="${2:-mkv}"

# Validate format
if [[ ! "$OUTPUT_FORMAT" =~ ^(mkv|mp4)$ ]]; then
    echo -e "${RED}Invalid format: $OUTPUT_FORMAT${NC}"
    echo "Use: mkv or mp4"
    exit 1
fi

# Check if file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}✗ File not found: $INPUT_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Input file exists${NC}"
echo "  File: $INPUT_FILE"
echo "  Size: $(du -h "$INPUT_FILE" | cut -f1)"
echo ""

# Extract filename
BASENAME=$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')
OUTPUT_FILE="${REPO_DIR}/upscaled/${BASENAME}_upscaled.${OUTPUT_FORMAT}"

# Rebuild container with latest code
echo -e "${BLUE}Step 1: Rebuilding container...${NC}"
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
docker compose down srgan-upscaler 2>/dev/null || true
docker compose up -d srgan-upscaler

sleep 2

if docker ps | grep -q srgan-upscaler; then
    echo -e "${GREEN}✓ Container running${NC}"
else
    echo -e "${RED}✗ Container not running${NC}"
    exit 1
fi

echo ""

# Clear old output
rm -f "$OUTPUT_FILE"

# Create test job
echo -e "${BLUE}Step 3: Creating upscale job...${NC}"

QUEUE_FILE="${REPO_DIR}/cache/queue.jsonl"
mkdir -p "${REPO_DIR}/cache"
mkdir -p "${REPO_DIR}/upscaled"

# Create job without HLS (direct output)
cat >> "$QUEUE_FILE" << EOF
{"input":"${INPUT_FILE}","output":"${OUTPUT_FILE}","streaming":false}
EOF

echo -e "${GREEN}✓ Job queued${NC}"
echo "  Input:  $INPUT_FILE"
echo "  Output: $OUTPUT_FILE"
echo "  Format: ${OUTPUT_FORMAT^^}"
echo ""

# Monitor processing
echo -e "${BLUE}Step 4: Processing (Ctrl+C to stop monitoring)...${NC}"
echo ""

# Show initial logs
docker logs srgan-upscaler 2>&1 | tail -5

echo ""
echo -e "${CYAN}Waiting for processing to start...${NC}"

# Wait for job to be picked up
TIMEOUT=30
ELAPSED=0
while [[ $ELAPSED -lt $TIMEOUT ]]; do
    if docker logs srgan-upscaler 2>&1 | tail -20 | grep -q "Starting direct file upscale"; then
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done

echo ""
echo ""

if docker logs srgan-upscaler 2>&1 | tail -20 | grep -q "Starting direct file upscale"; then
    echo -e "${GREEN}✓ Processing started${NC}"
    echo ""
    
    # Show processing info
    docker logs srgan-upscaler 2>&1 | grep -A 10 "Starting direct file upscale" | tail -11
    
    echo ""
    echo -e "${CYAN}Processing in background...${NC}"
    echo ""
    echo "Monitor progress:"
    echo "  docker logs -f srgan-upscaler"
    echo ""
    echo "Watch output file:"
    echo "  watch -n 2 'ls -lh \"$OUTPUT_FILE\" 2>/dev/null || echo \"Not created yet\"'"
    echo ""
    echo "Check for completion:"
    echo "  docker logs srgan-upscaler 2>&1 | grep \"Upscaling complete\""
    echo ""
else
    echo -e "${YELLOW}⚠ Processing not started yet${NC}"
    echo ""
    echo "Check logs:"
    echo "  docker logs srgan-upscaler"
    echo ""
    echo "Check queue:"
    echo "  cat $QUEUE_FILE"
fi

echo "=========================================================================="
echo -e "${CYAN}Test Job Created${NC}"
echo "=========================================================================="
echo ""

echo "The container will process the video in the background."
echo ""
echo "Expected processing time:"
echo "  • FFmpeg mode: 1-3 hours for 2hr movie"
echo "  • AI mode: 6-24 hours for 2hr movie"
echo ""
echo "When complete, output file will be at:"
echo "  $OUTPUT_FILE"
echo ""
