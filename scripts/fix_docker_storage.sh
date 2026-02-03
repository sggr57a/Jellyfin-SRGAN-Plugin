#!/bin/bash
#
# Fix Docker Storage/Overlay Corruption
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=========================================================================="
echo "Fix Docker Storage/Overlay Corruption"
echo "=========================================================================="
echo ""

echo -e "${YELLOW}This will clean up Docker storage and fix corruption issues${NC}"
echo ""
read -p "Press Enter to continue..."
echo ""

# Step 1: Check disk space
echo -e "${BLUE}Step 1: Checking disk space...${NC}"
echo ""

df -h /var/lib/docker

DISK_USAGE=$(df /var/lib/docker | tail -1 | awk '{print $5}' | sed 's/%//')

if [[ $DISK_USAGE -gt 90 ]]; then
    echo ""
    echo -e "${RED}⚠ WARNING: Disk is ${DISK_USAGE}% full!${NC}"
    echo "Docker needs free space to build images"
    echo ""
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Disk space OK (${DISK_USAGE}% used)${NC}"
fi

echo ""

# Step 2: Stop running containers
echo -e "${BLUE}Step 2: Stopping containers...${NC}"

cd /root/Jellyfin-SRGAN-Plugin 2>/dev/null || cd ~/Jellyfin-SRGAN-Plugin || cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

echo -e "${GREEN}✓ Containers stopped${NC}"
echo ""

# Step 3: Clean up Docker system
echo -e "${BLUE}Step 3: Cleaning Docker system...${NC}"
echo ""

# Remove stopped containers
echo "Removing stopped containers..."
docker container prune -f

echo ""

# Remove dangling images
echo "Removing dangling images..."
docker image prune -f

echo ""

# Remove unused build cache
echo "Removing build cache..."
docker builder prune -f

echo ""

echo -e "${GREEN}✓ Docker system cleaned${NC}"
echo ""

# Step 4: Restart Docker daemon
echo -e "${BLUE}Step 4: Restarting Docker daemon...${NC}"

systemctl restart docker

echo "Waiting for Docker to restart..."
sleep 5

# Wait for Docker to be ready
TIMEOUT=30
ELAPSED=0
while ! docker info >/dev/null 2>&1; do
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo -e "${RED}✗ Docker failed to start${NC}"
        exit 1
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done

echo ""
echo -e "${GREEN}✓ Docker daemon restarted${NC}"
echo ""

# Step 5: Verify Docker health
echo -e "${BLUE}Step 5: Verifying Docker health...${NC}"

docker info | grep -E "Storage Driver|Docker Root Dir"

echo -e "${GREEN}✓ Docker is healthy${NC}"
echo ""

# Step 6: Attempt build
echo "=========================================================================="
echo -e "${CYAN}Attempting Build${NC}"
echo "=========================================================================="
echo ""

cd /root/Jellyfin-SRGAN-Plugin 2>/dev/null || cd ~/Jellyfin-SRGAN-Plugin || cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "Building from: $(pwd)"
echo ""

if docker compose build --no-cache srgan-upscaler; then
    echo ""
    echo "=========================================================================="
    echo -e "${GREEN}✅ SUCCESS! Container built${NC}"
    echo "=========================================================================="
    echo ""
    echo "Next steps:"
    echo "  docker compose up -d"
    echo ""
else
    echo ""
    echo "=========================================================================="
    echo -e "${RED}❌ Build still failed${NC}"
    echo "=========================================================================="
    echo ""
    echo "Additional troubleshooting needed:"
    echo ""
    echo "1. Check Docker logs:"
    echo "   journalctl -u docker -n 50"
    echo ""
    echo "2. Try more aggressive cleanup:"
    echo "   docker system prune -a --volumes"
    echo "   (WARNING: Removes ALL unused Docker data)"
    echo ""
    echo "3. Check for filesystem errors:"
    echo "   dmesg | grep -i error"
    echo ""
    echo "4. Restart server:"
    echo "   reboot"
    echo ""
    exit 1
fi
