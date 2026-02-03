#!/bin/bash
#
# Fix Docker Volume Mounts for Media Access
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================================================="
echo "Fixing Docker Volume Mounts for Media File Access"
echo "=========================================================================="
echo ""

# Step 1: Find Jellyfin's media libraries
echo -e "${BLUE}Step 1: Finding Jellyfin media library paths...${NC}"

# Check Jellyfin library configuration
JELLYFIN_CONFIG_DIR="/var/lib/jellyfin/data"
LIBRARY_DB="${JELLYFIN_CONFIG_DIR}/library.db"

if [[ -f "${LIBRARY_DB}" ]]; then
    echo "✓ Found Jellyfin database"
else
    echo -e "${YELLOW}⚠ Jellyfin database not found${NC}"
    echo "  Checking common media locations..."
fi

# Common media paths to check
MEDIA_PATHS=(
    "/media"
    "/mnt/media"
    "/srv/media"
    "/data/media"
    "/var/lib/jellyfin/media"
    "/home/*/media"
)

echo ""
echo "Checking for media directories..."
FOUND_PATHS=()

for path in "${MEDIA_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        # Check if it has media files
        FILE_COUNT=$(find "$path" -maxdepth 3 -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" \) 2>/dev/null | wc -l)
        if [[ $FILE_COUNT -gt 0 ]]; then
            echo -e "  ${GREEN}✓${NC} $path (${FILE_COUNT} video files)"
            FOUND_PATHS+=("$path")
        fi
    fi
done

if [[ ${#FOUND_PATHS[@]} -eq 0 ]]; then
    echo -e "${RED}✗ No media directories found!${NC}"
    echo ""
    echo "Please specify your media path:"
    read -p "Enter path to Jellyfin media library: " MEDIA_PATH
    FOUND_PATHS=("$MEDIA_PATH")
fi

echo ""

# Step 2: Update docker-compose.yml
echo -e "${BLUE}Step 2: Updating docker-compose.yml with correct volume mounts...${NC}"

COMPOSE_FILE="${REPO_DIR}/docker-compose.yml"
BACKUP_FILE="${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

sudo cp "${COMPOSE_FILE}" "${BACKUP_FILE}"
echo "Backed up to: ${BACKUP_FILE}"
echo ""

# Create new volumes section
echo "Adding volume mounts for:"
for path in "${FOUND_PATHS[@]}"; do
    echo "  - ${path} → /data${path}"
done
echo ""

# Update the srgan-upscaler volumes section
# We need to mount each media path to the same path inside the container
# This way /media/movies/file.mkv on host = /media/movies/file.mkv in container

cat > /tmp/new_volumes.txt << EOF
    volumes:
      - ./cache:/app/cache
      - ./models:/app/models:ro
EOF

# Add each found media path
for path in "${FOUND_PATHS[@]}"; do
    echo "      - ${path}:${path}:ro" >> /tmp/new_volumes.txt
done

# Also keep upscaled output
echo "      - /mnt/media/upscaled:/data/upscaled" >> /tmp/new_volumes.txt

# Now update docker-compose.yml
# Find the srgan-upscaler service and replace its volumes section
python3 << 'EOPY'
import re
import sys

with open('/tmp/new_volumes.txt', 'r') as f:
    new_volumes = f.read()

compose_file = sys.argv[1]
with open(compose_file, 'r') as f:
    content = f.read()

# Find srgan-upscaler service and replace volumes
# Pattern: match from "volumes:" to next section (environment, deploy, etc.)
pattern = r'(  srgan-upscaler:.*?)(    volumes:.*?)(    environment:)'
replacement = r'\1' + new_volumes + '\n\1    environment:'

content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(compose_file, 'w') as f:
    f.write(content)

print("✓ docker-compose.yml updated")
EOPY "${COMPOSE_FILE}"

echo ""

# Step 3: Show what changed
echo -e "${BLUE}Step 3: Verifying new configuration...${NC}"
echo ""
echo "New volume mounts in docker-compose.yml:"
grep -A 10 "srgan-upscaler:" "${COMPOSE_FILE}" | grep -A 6 "volumes:" | sed 's/^/  /'
echo ""

# Step 4: Recreate container
echo -e "${BLUE}Step 4: Recreating Docker container with new mounts...${NC}"
cd "${REPO_DIR}"

docker compose down srgan-upscaler
docker compose up -d srgan-upscaler

echo -e "${GREEN}✓ Container recreated${NC}"
echo ""

# Step 5: Test volume mounts
echo -e "${BLUE}Step 5: Testing volume mounts in container...${NC}"

for path in "${FOUND_PATHS[@]}"; do
    echo "  Testing: ${path}"
    if docker compose exec srgan-upscaler test -d "${path}"; then
        FILE_COUNT=$(docker compose exec srgan-upscaler sh -c "find ${path} -maxdepth 3 -type f \( -name '*.mkv' -o -name '*.mp4' \) 2>/dev/null | wc -l")
        echo -e "    ${GREEN}✓${NC} Accessible in container (${FILE_COUNT} files)"
    else
        echo -e "    ${RED}✗${NC} NOT accessible in container"
    fi
done

echo ""
echo "=========================================================================="
echo -e "${GREEN}Docker Volumes Fixed!${NC}"
echo "=========================================================================="
echo ""
echo "Volume mounts configured:"
for path in "${FOUND_PATHS[@]}"; do
    echo "  ${path} → ${path} (read-only)"
done
echo "  /mnt/media/upscaled → /data/upscaled (read-write)"
echo ""
echo "Test it:"
echo "  1. Play a video in Jellyfin"
echo "  2. Check watchdog logs: tail -f /var/log/srgan-watchdog.log"
echo "  3. Container should find the input file"
echo ""
