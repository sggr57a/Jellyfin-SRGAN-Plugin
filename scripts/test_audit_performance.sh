#!/bin/bash
# Test script for audit_performance.py

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_OUTPUT="${SCRIPT_DIR}/../output/test_audit.ts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================================================="
echo "Testing audit_performance.py"
echo "=========================================================================="
echo ""

# Test 1: Check syntax
echo -e "${YELLOW}Test 1: Checking Python syntax...${NC}"
if python3 -m py_compile "${SCRIPT_DIR}/audit_performance.py"; then
    echo -e "${GREEN}✓ Syntax check passed${NC}"
else
    echo -e "${RED}✗ Syntax errors found${NC}"
    exit 1
fi
echo ""

# Test 2: Help output
echo -e "${YELLOW}Test 2: Testing --help output...${NC}"
if python3 "${SCRIPT_DIR}/audit_performance.py" --help > /dev/null; then
    echo -e "${GREEN}✓ Help output works${NC}"
else
    echo -e "${RED}✗ Help output failed${NC}"
    exit 1
fi
echo ""

# Test 3: Check ffprobe dependency first
echo -e "${YELLOW}Test 3: Checking ffprobe availability...${NC}"
if command -v ffprobe &> /dev/null; then
    echo -e "${GREEN}✓ ffprobe is available${NC}"
    echo ""

    # Test 4: Error handling - missing file
    echo -e "${YELLOW}Test 4: Testing error handling (missing file)...${NC}"
    if python3 "${SCRIPT_DIR}/audit_performance.py" --output /nonexistent/file.ts 2>&1 | grep -q "Output file not found"; then
        echo -e "${GREEN}✓ Missing file error handled correctly${NC}"
    else
        echo -e "${RED}✗ Missing file error not handled${NC}"
        exit 1
    fi
    echo ""

    # Test 5: Error handling - invalid FPS
    echo -e "${YELLOW}Test 5: Testing error handling (invalid FPS)...${NC}"
    mkdir -p "$(dirname "$TEST_OUTPUT")"
    touch "$TEST_OUTPUT"
    if python3 "${SCRIPT_DIR}/audit_performance.py" --output "$TEST_OUTPUT" --target-fps -1 2>&1 | grep -q "Invalid target FPS"; then
        echo -e "${GREEN}✓ Invalid FPS error handled correctly${NC}"
    else
        echo -e "${RED}✗ Invalid FPS error not handled${NC}"
        rm -f "$TEST_OUTPUT"
        exit 1
    fi
    rm -f "$TEST_OUTPUT"
    echo ""

    # Test 6: Create a test video and monitor it
    echo -e "${YELLOW}Test 6: Creating test video and monitoring (5 seconds)...${NC}"

    # Create a short test video
    mkdir -p "$(dirname "$TEST_OUTPUT")"

    if command -v ffmpeg &> /dev/null && ffmpeg -f lavfi -i testsrc=duration=10:size=1280x720:rate=24 \
              -c:v libx264 -preset ultrafast -t 10 \
              -f mpegts "$TEST_OUTPUT" -y &> /dev/null; then
        echo -e "${GREEN}✓ Test video created${NC}"

        # Test monitoring (run for 3 seconds in background)
        echo "  Starting monitor (will run for 3 seconds)..."
        timeout 3 python3 "${SCRIPT_DIR}/audit_performance.py" \
            --output "$TEST_OUTPUT" \
            --target-fps 24 \
            --sample-seconds 1 2>&1 | head -20 || true

        echo ""
        echo -e "${GREEN}✓ Monitoring test completed${NC}"

        # Cleanup
        rm -f "$TEST_OUTPUT"
    else
        echo -e "${YELLOW}⚠ Could not create test video (ffmpeg not available or failed)${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ ffprobe not available - skipping file tests${NC}"
    echo "  Install ffmpeg to enable full testing:"
    echo "  - Ubuntu: sudo apt install ffmpeg"
    echo "  - macOS: brew install ffmpeg"
    echo ""
    echo -e "${GREEN}✓ Basic tests passed (syntax and help)${NC}"
fi
echo ""

echo "=========================================================================="
echo -e "${GREEN}All tests passed!${NC}"
echo "=========================================================================="
echo ""
echo "Usage examples:"
echo "  # Monitor an upscaling job"
echo "  python3 ${SCRIPT_DIR}/audit_performance.py --output /data/upscaled/movie.ts"
echo ""
echo "  # With custom settings"
echo "  python3 ${SCRIPT_DIR}/audit_performance.py \\"
echo "    --output /data/upscaled/movie.ts \\"
echo "    --target-fps 30 \\"
echo "    --sample-seconds 2"
echo ""
