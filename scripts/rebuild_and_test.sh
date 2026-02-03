#!/bin/bash
#
# Rebuild Container and Test
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
echo "Rebuild and Test SRGAN Container"
echo "=========================================================================="
echo ""

# Step 1: Pull latest code
echo -e "${BLUE}Step 1: Pulling latest code...${NC}"
cd "${REPO_DIR}"

if git pull origin main; then
    echo -e "${GREEN}✓ Code updated${NC}"
else
    echo -e "${YELLOW}⚠ Git pull failed or no changes${NC}"
fi

echo ""

# Step 2: Stop current container
echo -e "${BLUE}Step 2: Stopping container...${NC}"

if docker compose down srgan-upscaler 2>/dev/null; then
    echo -e "${GREEN}✓ Container stopped${NC}"
else
    echo -e "${YELLOW}⚠ Container was not running${NC}"
fi

echo ""

# Step 3: Rebuild container
echo -e "${BLUE}Step 3: Rebuilding container (this may take a few minutes)...${NC}"
echo ""

# Verify we're in correct directory with required files
if [[ ! -f "docker-compose.yml" ]] || [[ ! -f "Dockerfile" ]]; then
    echo -e "${RED}✗ Missing docker-compose.yml or Dockerfile${NC}"
    echo "Current directory: $(pwd)"
    echo "docker-compose.yml exists: $(test -f docker-compose.yml && echo 'yes' || echo 'no')"
    echo "Dockerfile exists: $(test -f Dockerfile && echo 'yes' || echo 'no')"
    exit 1
fi

echo "Building from: $(pwd)"
echo ""

if docker compose build --no-cache srgan-upscaler; then
    echo ""
    echo -e "${GREEN}✓ Container rebuilt successfully${NC}"
else
    echo ""
    echo -e "${RED}✗ Build failed${NC}"
    echo ""
    echo "Debug info:"
    echo "  Directory: $(pwd)"
    echo "  Files present:"
    ls -la docker-compose.yml Dockerfile 2>&1 | head -5
    exit 1
fi

echo ""

# Step 4: Start container
echo -e "${BLUE}Step 4: Starting container...${NC}"

if docker compose up -d srgan-upscaler; then
    echo -e "${GREEN}✓ Container started${NC}"
else
    echo -e "${RED}✗ Failed to start container${NC}"
    exit 1
fi

echo ""

# Wait for container to initialize
echo "Waiting for container to initialize..."
sleep 3

# Step 5: Verify container is running
echo -e "${BLUE}Step 5: Verifying container status...${NC}"

if docker ps | grep -q srgan-upscaler; then
    echo -e "${GREEN}✓ Container is running${NC}"
else
    echo -e "${RED}✗ Container not running${NC}"
    echo ""
    echo "Check logs:"
    echo "  docker logs srgan-upscaler"
    exit 1
fi

echo ""

# Step 6: Check for errors in logs
echo -e "${BLUE}Step 6: Checking logs for errors...${NC}"

ERRORS=$(docker logs srgan-upscaler 2>&1 | grep -i "error\|traceback\|failed\|unrecognized" | wc -l)

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ No errors in logs${NC}"
else
    echo -e "${YELLOW}⚠ Found $ERRORS potential errors${NC}"
    echo ""
    echo "Recent log entries:"
    docker logs srgan-upscaler 2>&1 | tail -20 | sed 's/^/  /'
fi

echo ""

# Step 7: Verify fix is applied
echo -e "${BLUE}Step 7: Verifying NVENC fix...${NC}"

# Check if the Python file in the container has the fix
if docker compose exec -T srgan-upscaler grep -q "Use appropriate quality option based on encoder" /app/scripts/srgan_pipeline.py; then
    echo -e "${GREEN}✓ NVENC fix is present in container${NC}"
else
    echo -e "${RED}✗ NVENC fix NOT found in container${NC}"
    echo "The container may not have been rebuilt properly"
    exit 1
fi

echo ""

# Step 8: Test with a file (optional)
echo "=========================================================================="
echo -e "${CYAN}Container Ready for Testing${NC}"
echo "=========================================================================="
echo ""

echo "To test with a video file:"
echo "  sudo ./scripts/test_upscaling.sh '/mnt/media/MOVIES/Back to the Future (1985)/Back to the Future (1985) imdbid-tt0088763 [Bluray-1080p].mp4'"
echo ""

echo "Or manually queue a job:"
echo "  echo '{\"input\":\"/mnt/media/...\",\"output\":\"./upscaled/test.ts\",\"streaming\":true}' >> cache/queue.jsonl"
echo ""

echo "Monitor logs:"
echo "  docker logs -f srgan-upscaler"
echo ""

echo "Watch GPU:"
echo "  watch -n 1 nvidia-smi"
echo ""

echo -e "${GREEN}=========================================================================="
echo "Rebuild Complete!"
echo "==========================================================================${NC}"
echo ""
