#!/bin/bash
#
# Diagnose Path Issue - Why Container Can't Find Input File
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================================================="
echo "Diagnosing: Why Docker Container Can't Find Input File"
echo "=========================================================================="
echo ""

# 1. Check what path webhook is sending
echo -e "${BLUE}1. Checking recent webhook data from logs...${NC}"
if [[ -f "/var/log/srgan-watchdog.log" ]]; then
    echo "Recent webhook data:"
    grep -E '"Path":|Extracted file path:' /var/log/srgan-watchdog.log | tail -5 | sed 's/^/  /'
    
    # Extract last path
    LAST_PATH=$(grep 'Extracted file path:' /var/log/srgan-watchdog.log | tail -1 | awk -F': ' '{print $NF}' | tr -d ' ')
    
    if [[ -n "${LAST_PATH}" ]] && [[ "${LAST_PATH}" != "None" ]]; then
        echo ""
        echo "Last file path from webhook: ${LAST_PATH}"
        
        # Check if file exists on host
        if [[ -f "${LAST_PATH}" ]]; then
            echo -e "  ${GREEN}✓${NC} File EXISTS on host"
            ls -lh "${LAST_PATH}"
        else
            echo -e "  ${RED}✗${NC} File DOES NOT exist on host at this path"
        fi
    else
        echo ""
        echo -e "${YELLOW}⚠ No valid file path found in logs${NC}"
        echo "Play a video in Jellyfin to trigger webhook"
    fi
else
    echo -e "${YELLOW}⚠ Watchdog log not found${NC}"
fi
echo ""

# 2. Check current docker volume mounts
echo -e "${BLUE}2. Checking Docker volume mounts...${NC}"
echo "Current mounts in docker-compose.yml:"
grep -A 10 "srgan-upscaler:" "${REPO_DIR}/docker-compose.yml" | grep -A 6 "volumes:" | sed 's/^/  /'
echo ""

# 3. Check what paths are accessible in container
echo -e "${BLUE}3. Testing what paths container can access...${NC}"

if docker ps | grep -q srgan-upscaler; then
    echo "Container is running. Testing paths..."
    echo ""
    
    # Test common media paths
    TEST_PATHS=(
        "/media"
        "/mnt/media"
        "/data"
        "/srv"
        "/var/lib/jellyfin"
    )
    
    for path in "${TEST_PATHS[@]}"; do
        if docker compose -f "${REPO_DIR}/docker-compose.yml" exec -T srgan-upscaler test -d "${path}" 2>/dev/null; then
            FILE_COUNT=$(docker compose -f "${REPO_DIR}/docker-compose.yml" exec -T srgan-upscaler sh -c "find ${path} -maxdepth 3 -type f \( -name '*.mkv' -o -name '*.mp4' \) 2>/dev/null | wc -l" | tr -d ' \r')
            echo -e "  ${GREEN}✓${NC} ${path} - accessible (${FILE_COUNT} video files)"
        else
            echo -e "  ${RED}✗${NC} ${path} - NOT accessible"
        fi
    done
    
    # If we found a path from logs, test it specifically
    if [[ -n "${LAST_PATH}" ]] && [[ "${LAST_PATH}" != "None" ]]; then
        echo ""
        echo "Testing specific path from webhook: ${LAST_PATH}"
        if docker compose -f "${REPO_DIR}/docker-compose.yml" exec -T srgan-upscaler test -f "${LAST_PATH}" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} File IS accessible in container!"
            echo "  The container CAN see the file - issue may be elsewhere"
        else
            echo -e "  ${RED}✗${NC} File NOT accessible in container"
            echo "  This is why upscaling fails!"
            echo ""
            echo "  File exists on host: $(test -f "${LAST_PATH}" && echo "YES" || echo "NO")"
            echo "  Container needs volume mount for: $(dirname "${LAST_PATH}")"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Container not running${NC}"
    echo "Start it: docker compose -f ${REPO_DIR}/docker-compose.yml up -d srgan-upscaler"
fi
echo ""

# 4. Find where Jellyfin's media actually is
echo -e "${BLUE}4. Finding Jellyfin's actual media directories...${NC}"

# Check Jellyfin configuration for library paths
if [[ -d "/var/lib/jellyfin/data" ]]; then
    echo "Searching Jellyfin configuration..."
    
    # Look for media paths in configuration
    MEDIA_DIRS=$(find /var/lib/jellyfin/data -name "*.xml" -exec grep -h "<Path>" {} \; 2>/dev/null | \
                 sed 's/<Path>//g;s/<\/Path>//g' | \
                 grep -E "^/" | \
                 sort -u)
    
    if [[ -n "${MEDIA_DIRS}" ]]; then
        echo "Found media library paths in Jellyfin config:"
        echo "${MEDIA_DIRS}" | while read -r path; do
            if [[ -d "$path" ]]; then
                echo -e "  ${GREEN}✓${NC} $path"
            else
                echo -e "  ${YELLOW}⚠${NC} $path (in config but doesn't exist)"
            fi
        done
    else
        echo "  No library paths found in configuration"
    fi
fi
echo ""

# 5. Provide solution
echo "=========================================================================="
echo -e "${YELLOW}SOLUTION${NC}"
echo "=========================================================================="
echo ""

echo "Your Jellyfin media files need to be mounted in the Docker container."
echo ""
echo "Current docker-compose.yml mounts:"
echo "  - /mnt/media:/data:rslave"
echo ""

if [[ -n "${LAST_PATH}" ]] && [[ "${LAST_PATH}" != "None" ]]; then
    BASE_PATH=$(echo "${LAST_PATH}" | cut -d/ -f1-3)
    echo "Based on webhook path (${LAST_PATH}), you need:"
    echo "  - ${BASE_PATH}:${BASE_PATH}:ro"
    echo ""
    echo "Run this to auto-fix:"
    echo "  sudo ./scripts/fix_docker_volumes.sh"
else
    echo "To auto-detect and fix volume mounts:"
    echo "  sudo ./scripts/fix_docker_volumes.sh"
fi

echo ""
echo "Or manually edit ${REPO_DIR}/docker-compose.yml:"
echo ""
echo "  srgan-upscaler:"
echo "    volumes:"
echo "      - /YOUR/MEDIA/PATH:/YOUR/MEDIA/PATH:ro  ← Add this"
echo "      - ./cache:/app/cache"
echo "      - ./models:/app/models:ro"
echo ""
echo "Then recreate container:"
echo "  cd ${REPO_DIR}"
echo "  docker compose down srgan-upscaler"
echo "  docker compose up -d srgan-upscaler"
echo ""

# 6. Quick test command
if [[ -n "${LAST_PATH}" ]] && [[ "${LAST_PATH}" != "None" ]] && [[ -f "${LAST_PATH}" ]]; then
    echo "=========================================================================="
    echo "Quick Test Command"
    echo "=========================================================================="
    echo ""
    echo "Test if container can access the file:"
    echo ""
    echo "  docker compose -f ${REPO_DIR}/docker-compose.yml exec srgan-upscaler test -f '${LAST_PATH}' && echo 'FILE FOUND' || echo 'FILE NOT FOUND'"
    echo ""
fi
