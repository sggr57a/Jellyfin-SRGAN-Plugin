#!/bin/bash
#
# Quick Fix for Docker Build Context Error
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=========================================================================="
echo "Fix Docker Build Context Error"
echo "=========================================================================="
echo ""

# Find repository directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}Checking repository location...${NC}"
echo "Repository: ${REPO_DIR}"
echo ""

# Verify we're in a git repository
if [[ ! -d "${REPO_DIR}/.git" ]]; then
    echo -e "${RED}✗ Not a git repository${NC}"
    echo "Please run this from within the Jellyfin-SRGAN-Plugin directory"
    exit 1
fi

cd "${REPO_DIR}"

# Check current branch
BRANCH=$(git branch --show-current)
echo "Current branch: ${BRANCH}"
echo ""

# Stash any local changes
echo -e "${BLUE}Saving any local changes...${NC}"
git stash save "Auto-stash before fix" 2>/dev/null || true

# Pull latest
echo -e "${BLUE}Pulling latest code...${NC}"
git fetch origin
git reset --hard origin/main
echo -e "${GREEN}✓ Code updated${NC}"
echo ""

# Verify docker-compose.yml is correct
echo -e "${BLUE}Verifying docker-compose.yml...${NC}"

if [[ ! -f "docker-compose.yml" ]]; then
    echo -e "${RED}✗ docker-compose.yml not found!${NC}"
    exit 1
fi

# Check the build context line
if grep -q "context: \." docker-compose.yml; then
    echo -e "${GREEN}✓ Build context is correct (context: .)${NC}"
else
    echo -e "${RED}✗ Build context is incorrect${NC}"
    echo "Fixing docker-compose.yml..."
    
    # Show what's wrong
    echo ""
    echo "Current build section:"
    grep -A 2 "build:" docker-compose.yml | head -3
    echo ""
    
    # Try to pull again
    git fetch origin
    git checkout origin/main -- docker-compose.yml
    echo -e "${GREEN}✓ docker-compose.yml restored from repository${NC}"
fi

echo ""

# Verify Dockerfile exists
echo -e "${BLUE}Verifying Dockerfile...${NC}"
if [[ -f "Dockerfile" ]]; then
    echo -e "${GREEN}✓ Dockerfile found${NC}"
else
    echo -e "${RED}✗ Dockerfile not found${NC}"
    echo "Restoring from repository..."
    git checkout origin/main -- Dockerfile
fi

echo ""

# Show the build configuration
echo -e "${CYAN}Current build configuration:${NC}"
echo ""
grep -A 5 "build:" docker-compose.yml | head -6
echo ""

# Verify structure
echo -e "${BLUE}Repository structure:${NC}"
ls -la docker-compose.yml Dockerfile requirements.txt 2>/dev/null || echo "Some files missing"
echo ""

# Now try to build
echo "=========================================================================="
echo -e "${CYAN}Attempting Docker Build${NC}"
echo "=========================================================================="
echo ""

echo "Building from: $(pwd)"
echo "Command: docker compose build srgan-upscaler"
echo ""
read -p "Press Enter to attempt build..."
echo ""

if docker compose build srgan-upscaler; then
    echo ""
    echo "=========================================================================="
    echo -e "${GREEN}✅ SUCCESS! Build completed${NC}"
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
    echo "Debug information:"
    echo ""
    echo "1. Current directory:"
    pwd
    echo ""
    echo "2. Docker Compose version:"
    docker compose version
    echo ""
    echo "3. Build section in docker-compose.yml:"
    grep -A 5 "build:" docker-compose.yml
    echo ""
    echo "4. Files in current directory:"
    ls -la *.yml *.txt Dockerfile 2>/dev/null
    echo ""
    echo "Please share this output for further debugging."
    exit 1
fi
