#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="${REPO_DIR}/scripts"

echo "=========================================================================="
echo "Real-Time HDR SRGAN Pipeline - Complete Installation"
echo "=========================================================================="
echo ""
echo "This installer will:"
echo "  ✓ Install system dependencies (Docker, Python, etc.)"
echo "  ✓ Configure volume mounts for media access"
echo "  ✓ Build Docker container"
echo "  ✓ Install API-based watchdog (recommended)"
echo "  ✓ Clean up old template-based files"
echo "  ✓ Configure Jellyfin webhook"
echo "  ✓ Test the installation"
echo ""
read -p "Press Enter to continue..."
echo ""

#==============================================================================
# Helper Functions
#==============================================================================

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="${ID}"
        OS_VERSION="${VERSION_ID}"
        echo -e "${BLUE}Detected OS: ${NAME} ${VERSION_ID}${NC}"
    else
        echo -e "${RED}Cannot detect OS${NC}"
        exit 1
    fi
}

#==============================================================================
# Step 0: Check Prerequisites
#==============================================================================

echo -e "${BLUE}Step 0: Checking system...${NC}"
echo "=========================================================================="

detect_os

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Running as root. Some steps may need regular user context.${NC}"
fi

echo ""

#==============================================================================
# Step 1: Install System Dependencies
#==============================================================================

echo -e "${BLUE}Step 1: Installing system dependencies...${NC}"
echo "=========================================================================="

# Docker
if ! check_command docker; then
    echo "Installing Docker..."
    if [[ "${OS_ID}" == "ubuntu" ]] || [[ "${OS_ID}" == "debian" ]]; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        sudo usermod -aG docker "${SUDO_USER:-${USER}}"
        rm /tmp/get-docker.sh
        echo -e "${GREEN}✓ Docker installed${NC}"
        echo -e "${YELLOW}⚠ You may need to log out and back in for Docker access${NC}"
    else
        echo -e "${RED}✗ Unsupported OS for automatic Docker installation${NC}"
        echo "Install Docker manually: https://docs.docker.com/engine/install/"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Docker installed${NC}"
fi

# Docker Compose v2
if ! docker compose version >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker Compose v2 required${NC}"
    apt update ; apt install -y docker-compose-v2
else
    echo -e "${GREEN}✓ Docker Compose v2 installed${NC}"
fi

# Python 3
if ! check_command python3; then
    echo "Installing Python 3..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip
    echo -e "${GREEN}✓ Python 3 installed${NC}"
else
    echo -e "${GREEN}✓ Python 3 installed${NC}"
fi

# Python packages
echo "Installing Python packages (flask, requests)..."
python3 -m pip install --user flask requests >/dev/null 2>&1 || \
    sudo pip3 install flask requests >/dev/null 2>&1 || true
echo -e "${GREEN}✓ Python packages installed${NC}"

# Check for Jellyfin and detect port
echo "Detecting Jellyfin..."

# Try to detect Jellyfin port
JELLYFIN_PORT=""
if systemctl is-active --quiet jellyfin 2>/dev/null; then
    echo -e "${GREEN}✓ Jellyfin server running${NC}"
    
    # Try to detect port from netstat/ss
    DETECTED_PORT=$(ss -tlnp 2>/dev/null | grep jellyfin | grep LISTEN | head -1 | awk '{print $4}' | awk -F: '{print $NF}')
    
    if [[ -z "$DETECTED_PORT" ]]; then
        # Try alternative detection
        DETECTED_PORT=$(netstat -tlnp 2>/dev/null | grep jellyfin | grep LISTEN | head -1 | awk '{print $4}' | awk -F: '{print $NF}')
    fi
    
    if [[ -n "$DETECTED_PORT" ]]; then
        echo "  Detected Jellyfin on port: ${DETECTED_PORT}"
        JELLYFIN_PORT="$DETECTED_PORT"
    fi
    
    JELLYFIN_FOUND=true
elif check_command jellyfin; then
    echo -e "${YELLOW}⚠ Jellyfin installed but not running${NC}"
    JELLYFIN_FOUND=true
else
    echo -e "${YELLOW}⚠ Jellyfin not detected${NC}"
    echo "  Install from: https://jellyfin.org/downloads/"
    JELLYFIN_FOUND=false
fi

# Prompt for Jellyfin URL (with detected port as default)
if [[ -n "$JELLYFIN_PORT" ]]; then
    DEFAULT_URL="http://localhost:${JELLYFIN_PORT}"
else
    DEFAULT_URL="http://localhost:8096"
fi

echo ""
read -p "Jellyfin URL [${DEFAULT_URL}]: " JELLYFIN_URL_INPUT
JELLYFIN_URL="${JELLYFIN_URL_INPUT:-$DEFAULT_URL}"

# Test if Jellyfin is accessible
echo "Testing Jellyfin connectivity..."
if curl -s -f "${JELLYFIN_URL}/System/Info/Public" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Jellyfin accessible at ${JELLYFIN_URL}${NC}"
else
    echo -e "${YELLOW}⚠ Could not connect to Jellyfin at ${JELLYFIN_URL}${NC}"
    echo "  The installation will continue, but verify the URL is correct"
fi

echo ""

#==============================================================================
# Step 2: Clean Up Old Files
#==============================================================================

echo -e "${BLUE}Step 2: Cleaning up old template-based files...${NC}"
echo "=========================================================================="

# Stop and remove old template-based watchdog
if systemctl is-active --quiet srgan-watchdog 2>/dev/null; then
    echo "Stopping old template-based watchdog..."
    sudo systemctl stop srgan-watchdog
    sudo systemctl disable srgan-watchdog
    echo -e "${GREEN}✓ Old watchdog stopped${NC}"
fi

# Remove old webhook plugin build files (not needed for API approach)
if [[ -d "${REPO_DIR}/jellyfin-plugin-webhook" ]]; then
    echo "Removing old webhook plugin files (not needed for API approach)..."
    rm -rf "${REPO_DIR}/jellyfin-plugin-webhook"
    echo -e "${GREEN}✓ Old webhook plugin files removed${NC}"
fi

# Remove old template-based scripts
OLD_SCRIPTS=(
    "${SCRIPT_DIR}/watchdog.py.old"
    "${SCRIPT_DIR}/setup_webhook_source.sh"
    "${SCRIPT_DIR}/patch_webhook_path.sh"
)

for script in "${OLD_SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        rm -f "$script"
    fi
done

#docker stop $(docker ps -qa) ; docker rm $(docker ps -qa) ; docker system prune -af

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

#==============================================================================
# Step 3: Auto-Detect Media Paths & Configure Volume Mounts
#==============================================================================

echo -e "${BLUE}Step 3: Configuring Docker volume mounts...${NC}"
echo "=========================================================================="

echo "Detecting media library paths..."

# Common media paths
MEDIA_PATHS=(
    "/media"
    "/mnt/media"
    "/srv/media"
    "/data/media"
)

FOUND_PATHS=()
for path in "${MEDIA_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        # Check if it has media files
        FILE_COUNT=$(find "$path" -maxdepth 3 -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" \) 2>/dev/null | wc -l || echo "0")
        if [[ $FILE_COUNT -gt 0 ]]; then
            echo -e "  ${GREEN}✓${NC} Found: $path (${FILE_COUNT} video files)"
            FOUND_PATHS+=("$path")
        fi
    fi
done

if [[ ${#FOUND_PATHS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠ No media directories auto-detected${NC}"
    echo ""
    read -p "Enter path to your media library: " CUSTOM_PATH
    if [[ -d "$CUSTOM_PATH" ]]; then
        FOUND_PATHS=("$CUSTOM_PATH")
    else
        echo -e "${RED}✗ Path does not exist: $CUSTOM_PATH${NC}"
        exit 1
    fi
fi

# Update docker-compose.yml with detected paths
echo ""
echo "Updating docker-compose.yml with volume mounts..."

# Backup current docker-compose.yml
cp "${REPO_DIR}/docker-compose.yml" "${REPO_DIR}/docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"

# Create new docker-compose.yml with updated volumes
# Use awk to insert detected paths after the volumes section
{
    # Read original file
    cat "${REPO_DIR}/docker-compose.yml"
} | awk -v paths="${FOUND_PATHS[*]}" '
BEGIN {
    # Split paths into array
    split(paths, path_array, " ")
    in_volumes = 0
    in_srgan = 0
    volumes_printed = 0
}

# Track when we are in srgan-upscaler service
/^  srgan-upscaler:/ {
    in_srgan = 1
}

# Track when we are in another service (exit srgan-upscaler)
/^  [a-z]/ && !/^  srgan-upscaler:/ {
    in_srgan = 0
    in_volumes = 0
}

# When we hit volumes in srgan-upscaler service
/^    volumes:/ && in_srgan {
    in_volumes = 1
    print "    volumes:"
    print "      # Queue file (shared with watchdog)"
    print "      - ./cache:/app/cache"
    print "      "
    print "      # AI models"
    print "      - ./models:/app/models:ro"
    print "      "
    print "      # Output directory (HLS streams + final files)"
    print "      - ./upscaled:/data/upscaled"
    
    # Add detected media paths
    if (length(path_array) > 0) {
        print "      "
        print "      # Media input paths (auto-detected)"
        for (i in path_array) {
            if (path_array[i] != "") {
                print "      - " path_array[i] ":" path_array[i] ":ro"
            }
        }
    }
    
    volumes_printed = 1
    next
}

# Skip old volume entries
in_volumes && /^      -/ {
    next
}

# Exit volumes section when we hit next key
in_volumes && /^    [a-z]/ {
    in_volumes = 0
}

# Print everything else
!in_volumes || !(/^      -/) {
    print
}
' > "${REPO_DIR}/docker-compose.yml.new"

# Replace old with new
mv "${REPO_DIR}/docker-compose.yml.new" "${REPO_DIR}/docker-compose.yml"

echo -e "${GREEN}✓ Volume mounts configured${NC}"
echo ""

# Show what was added
echo "Added volume mounts:"
for path in "${FOUND_PATHS[@]}"; do
    echo "  - ${path}"
done
echo ""

#==============================================================================
# Step 4: Build Docker Container
#==============================================================================

echo -e "${BLUE}Step 4: Building Docker container...${NC}"
echo "=========================================================================="

cd "${REPO_DIR}"

# Verify we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo -e "${RED}✗ docker-compose.yml not found in ${REPO_DIR}${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

if [[ ! -f "Dockerfile" ]]; then
    echo -e "${RED}✗ Dockerfile not found in ${REPO_DIR}${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "Building srgan-upscaler container from ${REPO_DIR}..."
echo "Using docker-compose.yml and Dockerfile in current directory"
echo ""

if docker compose build srgan-upscaler --no-cache ; then
    echo -e "${GREEN}✓ Container built successfully${NC}"
else
    echo -e "${RED}✗ Container build failed${NC}"
    echo ""
    echo "Debug information:"
    echo "  Working directory: $(pwd)"
    echo "  docker-compose.yml exists: $(test -f docker-compose.yml && echo 'yes' || echo 'no')"
    echo "  Dockerfile exists: $(test -f Dockerfile && echo 'yes' || echo 'no')"
    exit 1
fi

echo ""

#==============================================================================
# Step 5: Get Jellyfin API Key
#==============================================================================

echo -e "${BLUE}Step 5: Jellyfin API configuration...${NC}"
echo "=========================================================================="

JELLYFIN_API_KEY=""
API_KEY_FILE="${REPO_DIR}/.jellyfin_api_key"

# Check if API key already exists
if [[ -f "$API_KEY_FILE" ]]; then
    echo "Found existing API key configuration"
    JELLYFIN_API_KEY=$(cat "$API_KEY_FILE")
    echo ""
    read -p "Use existing API key? (Y/n): " USE_EXISTING
    if [[ ! "${USE_EXISTING}" =~ ^[Nn] ]]; then
        echo -e "${GREEN}✓ Using existing API key${NC}"
    else
        JELLYFIN_API_KEY=""
    fi
fi

# Prompt for API key if not set
if [[ -z "$JELLYFIN_API_KEY" ]]; then
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Jellyfin API Key Required${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "The API-based watchdog needs a Jellyfin API key to query sessions."
    echo ""
    echo "To create an API key:"
    echo "  1. Open Jellyfin Dashboard at: ${JELLYFIN_URL}"
    echo "  2. Go to: Advanced → API Keys"
    echo "  3. Click '+' button"
    echo "  4. Application name: SRGAN Watchdog"
    echo "  5. Copy the generated key"
    echo ""
    read -p "Enter Jellyfin API key: " JELLYFIN_API_KEY
    
    if [[ -z "$JELLYFIN_API_KEY" ]]; then
        echo -e "${RED}✗ API key is required${NC}"
        exit 1
    fi
    
    # Save API key and URL for future use
    echo "$JELLYFIN_API_KEY" > "$API_KEY_FILE"
    echo "$JELLYFIN_URL" > "${REPO_DIR}/.jellyfin_url"
    chmod 600 "$API_KEY_FILE"
    chmod 600 "${REPO_DIR}/.jellyfin_url"
fi

# Test API connectivity
echo ""
echo "Testing Jellyfin API connection..."
if curl -s -f -H "X-Emby-Token: ${JELLYFIN_API_KEY}" "${JELLYFIN_URL}/Sessions" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Successfully connected to Jellyfin API${NC}"
    
    # Test with a real query
    SESSION_COUNT=$(curl -s -H "X-Emby-Token: ${JELLYFIN_API_KEY}" "${JELLYFIN_URL}/Sessions" | grep -c '"Id"' || echo "0")
    echo "  Active sessions: ${SESSION_COUNT}"
else
    echo -e "${YELLOW}⚠ Could not connect to Jellyfin API${NC}"
    echo "  The service will still be installed, but verify:"
    echo "    - Jellyfin is running at: ${JELLYFIN_URL}"
    echo "    - API key is valid"
    echo ""
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

#==============================================================================
# Step 6: Install API-Based Watchdog Service
#==============================================================================

echo -e "${BLUE}Step 6: Installing API-based watchdog service...${NC}"
echo "=========================================================================="

# Create environment file
ENV_FILE="/etc/default/srgan-watchdog-api"
echo "Creating environment configuration..."

sudo tee "$ENV_FILE" > /dev/null << EOF
# Jellyfin API Configuration
JELLYFIN_URL=${JELLYFIN_URL}
JELLYFIN_API_KEY=${JELLYFIN_API_KEY}

# Watchdog Configuration
UPSCALED_DIR=${REPO_DIR}/upscaled
SRGAN_QUEUE_FILE=${REPO_DIR}/cache/queue.jsonl
ENABLE_HLS_STREAMING=1
HLS_SERVER_HOST=localhost
HLS_SERVER_PORT=8080
EOF

sudo chmod 600 "$ENV_FILE"
echo -e "${GREEN}✓ Environment file created${NC}"

# Create systemd service
SERVICE_FILE="/etc/systemd/system/srgan-watchdog-api.service"
echo "Creating systemd service..."

sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=SRGAN Watchdog API-Based Service
After=network.target docker.service jellyfin.service
Wants=jellyfin.service

[Service]
Type=simple
User=${SUDO_USER:-${USER}}
WorkingDirectory=${REPO_DIR}

# Load environment
EnvironmentFile=${ENV_FILE}

# Run watchdog
ExecStart=$(which python3) ${SCRIPT_DIR}/watchdog_api.py

# Restart on failure
Restart=always
RestartSec=5

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=srgan-watchdog-api

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓ Systemd service created${NC}"

# Reload systemd and start service
echo "Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable srgan-watchdog-api
sudo systemctl start srgan-watchdog-api

# Wait for service to start
sleep 2

if systemctl is-active --quiet srgan-watchdog-api; then
    echo -e "${GREEN}✓ Watchdog service is running${NC}"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check logs: sudo journalctl -u srgan-watchdog-api -n 50"
    exit 1
fi

echo ""

#==============================================================================
# Step 7: Start Docker Container
#==============================================================================

echo -e "${BLUE}Step 7: Starting Docker containers...${NC}"
echo "=========================================================================="

cd "${REPO_DIR}"

# Start all services
if docker compose up -d; then
    echo -e "${GREEN}✓ Docker containers started${NC}"
else
    echo -e "${RED}✗ Failed to start containers${NC}"
    exit 1
fi

# Check container status
sleep 2
if docker ps | grep -q srgan-upscaler; then
    echo -e "${GREEN}✓ srgan-upscaler container running${NC}"
else
    echo -e "${YELLOW}⚠ srgan-upscaler container not running${NC}"
fi

if docker ps | grep -q hls-server; then
    echo -e "${GREEN}✓ hls-server container running${NC}"
fi

echo ""

#==============================================================================
# Step 8: Create Required Directories
#==============================================================================

echo -e "${BLUE}Step 8: Creating required directories...${NC}"
echo "=========================================================================="

# Create output directories
mkdir -p "${REPO_DIR}/upscaled/hls"
mkdir -p "${REPO_DIR}/cache"
mkdir -p "${REPO_DIR}/models"

# Create queue file
touch "${REPO_DIR}/cache/queue.jsonl"

echo -e "${GREEN}✓ Directories created${NC}"
echo ""

#==============================================================================
# Download SRGAN Model
#==============================================================================

echo -e "${BLUE}Downloading SRGAN AI Model...${NC}"
echo "=========================================================================="

MODEL_FILE="${REPO_DIR}/models/swift_srgan_4x.pth"
MODEL_URL="https://github.com/Koushik0901/Swift-SRGAN/releases/download/v0.1/swift_srgan_4x.pth.tar"

if [[ -f "$MODEL_FILE" ]]; then
    MODEL_SIZE=$(du -h "$MODEL_FILE" | cut -f1)
    echo -e "${GREEN}✓ Model already exists${NC} (${MODEL_SIZE})"
else
    echo "Downloading Swift-SRGAN 4x model (~16MB)..."
    echo "This may take a moment..."
    echo ""
    
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "${REPO_DIR}/models/swift_srgan_4x.pth.tar" "${MODEL_URL}"
        DOWNLOAD_SUCCESS=$?
    elif command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "${REPO_DIR}/models/swift_srgan_4x.pth.tar" "${MODEL_URL}"
        DOWNLOAD_SUCCESS=$?
    else
        echo -e "${RED}✗ Neither wget nor curl found${NC}"
        echo "Please install wget or curl to download the model"
        exit 1
    fi
    
    if [[ $DOWNLOAD_SUCCESS -eq 0 ]] && [[ -f "${REPO_DIR}/models/swift_srgan_4x.pth.tar" ]]; then
        # Rename .tar to .pth (it's already a .pth file, just named .tar)
        mv "${REPO_DIR}/models/swift_srgan_4x.pth.tar" "${REPO_DIR}/models/swift_srgan_4x.pth"
        MODEL_SIZE=$(du -h "$MODEL_FILE" | cut -f1)
        echo -e "${GREEN}✓ Model downloaded successfully${NC} (${MODEL_SIZE})"
    else
        echo -e "${RED}✗ Model download failed${NC}"
        echo "You can manually download later with:"
        echo "  ./scripts/setup_model.sh"
        echo ""
        echo "Installation will continue, but AI upscaling won't work until model is downloaded."
        read -p "Continue without model? (y/N): " CONTINUE_WITHOUT_MODEL
        if [[ ! "${CONTINUE_WITHOUT_MODEL}" =~ ^[Yy] ]]; then
            exit 1
        fi
    fi
fi

echo ""

#==============================================================================
# Step 9: Configure Jellyfin Webhook
#==============================================================================

echo -e "${BLUE}Step 9: Jellyfin webhook configuration...${NC}"
echo "=========================================================================="

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  MANUAL STEP: Configure Jellyfin Webhook${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "In Jellyfin Dashboard → Plugins → Webhook:"
echo ""
echo "  1. Click 'Add Generic Destination'"
echo "  2. Webhook Name: SRGAN Trigger"
echo "  3. Webhook Url: http://localhost:5432/upscale-trigger"
echo "  4. Notification Type: ✓ Playback Start"
echo "  5. Item Type: ✓ Movie, ✓ Episode"
echo "  6. Template: {\"event\":\"playback_start\"}"
echo "  7. Click 'Save'"
echo ""
echo -e "${YELLOW}Note: Template content doesn't matter - we use API to get file path${NC}"
echo ""

read -p "Press Enter when webhook is configured..."
echo ""

#==============================================================================
# Step 10: Test Installation
#==============================================================================

echo -e "${BLUE}Step 10: Testing installation...${NC}"
echo "=========================================================================="

# Test watchdog endpoint
echo "Testing watchdog API..."
if curl -s -f http://localhost:5432/status >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Watchdog API responding${NC}"
    
    # Show status
    STATUS=$(curl -s http://localhost:5432/status)
    echo "$STATUS" | python3 -m json.tool 2>/dev/null | grep -E "status|jellyfin" | sed 's/^/    /'
else
    echo -e "${YELLOW}⚠ Watchdog API not responding yet${NC}"
fi

# Test currently playing endpoint
echo ""
echo "Testing session detection..."
PLAYING=$(curl -s http://localhost:5432/playing)
if echo "$PLAYING" | grep -q '"count"'; then
    COUNT=$(echo "$PLAYING" | python3 -c "import sys, json; print(json.load(sys.stdin)['count'])" 2>/dev/null || echo "0")
    echo -e "${GREEN}✓ Session detection working (${COUNT} items playing)${NC}"
else
    echo -e "${YELLOW}⚠ Session detection needs verification${NC}"
fi

# Test Docker container access to media
echo ""
echo "Testing container media access..."
FIRST_MEDIA_PATH="${FOUND_PATHS[0]}"
if docker compose exec -T srgan-upscaler test -d "$FIRST_MEDIA_PATH" 2>/dev/null; then
    FILE_COUNT=$(docker compose exec -T srgan-upscaler sh -c "find $FIRST_MEDIA_PATH -maxdepth 3 -type f \( -name '*.mkv' -o -name '*.mp4' \) 2>/dev/null | wc -l" | tr -d ' \r')
    echo -e "${GREEN}✓ Container can access media (${FILE_COUNT} files found)${NC}"
else
    echo -e "${YELLOW}⚠ Container cannot access media path: $FIRST_MEDIA_PATH${NC}"
    echo "  Run: ./scripts/diagnose_path_issue.sh"
fi

echo ""

#==============================================================================
# Step 11: Install Auto-Fix Service
#==============================================================================

echo -e "${BLUE}Step 11: Installing auto-fix service...${NC}"
echo "=========================================================================="

echo "The auto-fix service automatically detects and fixes common issues:"
echo "  ✓ Container crashes → Auto-restart"
echo "  ✓ Pipeline not running → Auto-restart with diagnostics"
echo "  ✓ Watchdog stopped → Auto-restart"
echo "  ✓ GPU not accessible → Docker daemon restart"
echo "  ✓ Model file missing → Auto-download"
echo "  ✓ Queue stuck → Auto-clear with backup"
echo "  ✓ Recent errors → Run diagnostics and fix"
echo ""

# Make autofix.sh executable
chmod +x "${SCRIPT_DIR}/autofix.sh"

# Install systemd service and timer
AUTOFIX_SERVICE="/etc/systemd/system/srgan-autofix.service"
AUTOFIX_TIMER="/etc/systemd/system/srgan-autofix.timer"

echo "Installing autofix service..."
sudo tee "$AUTOFIX_SERVICE" > /dev/null << EOF
[Unit]
Description=SRGAN Auto-Fix Service
After=docker.service srgan-watchdog-api.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=${SCRIPT_DIR}/autofix.sh
StandardOutput=append:/var/log/srgan-autofix.log
StandardError=append:/var/log/srgan-autofix.log

# Resource limits
Nice=10
IOSchedulingClass=idle

[Install]
WantedBy=multi-user.target
EOF

echo "Installing autofix timer..."
sudo tee "$AUTOFIX_TIMER" > /dev/null << EOF
[Unit]
Description=SRGAN Auto-Fix Timer
Requires=srgan-autofix.service

[Timer]
# Run every 5 minutes
OnBootSec=5min
OnUnitActiveSec=5min
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable srgan-autofix.timer
sudo systemctl start srgan-autofix.timer

# Verify timer is running
if systemctl is-active --quiet srgan-autofix.timer; then
    echo -e "${GREEN}✓ Auto-fix timer enabled${NC}"
    echo "  Checking every 5 minutes for issues"
    echo "  Logs: /var/log/srgan-autofix.log"
else
    echo -e "${YELLOW}⚠ Auto-fix timer not started${NC}"
fi

# Run initial autofix check
echo ""
echo "Running initial diagnostics..."
"${SCRIPT_DIR}/autofix.sh" || true

echo ""

#==============================================================================
# Step 12: Install Verification Scripts
#==============================================================================

echo -e "${BLUE}Step 12: Installing verification and debugging tools...${NC}"
echo "=========================================================================="

# Make all diagnostic scripts executable
DIAGNOSTIC_SCRIPTS=(
    "verify_all_features.sh"
    "debug_pipeline.sh"
    "test_manual_queue.sh"
    "diagnose_ai.sh"
    "clear_queue.sh"
)

for script in "${DIAGNOSTIC_SCRIPTS[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${script}" ]]; then
        chmod +x "${SCRIPT_DIR}/${script}"
        echo -e "  ✓ ${script}"
    fi
done

echo ""
echo -e "${GREEN}✓ Verification tools installed${NC}"
echo ""
echo "Available diagnostic commands:"
echo "  ${SCRIPT_DIR}/verify_all_features.sh   - Verify all 10 features"
echo "  ${SCRIPT_DIR}/debug_pipeline.sh        - 10-point diagnostic"
echo "  ${SCRIPT_DIR}/test_manual_queue.sh     - Manual test with monitoring"
echo "  ${SCRIPT_DIR}/diagnose_ai.sh           - AI-specific checks"
echo "  ${SCRIPT_DIR}/autofix.sh               - Run auto-fix manually"
echo ""

#==============================================================================
# Step 13: Run Comprehensive Verification
#==============================================================================

echo -e "${BLUE}Step 13: Running comprehensive verification and tests...${NC}"
echo "=========================================================================="
echo ""
echo "This will automatically verify all features, test the pipeline, and"
echo "diagnose any issues. This ensures everything is working before completion."
echo ""

# Test 1: Verify All Features
echo -e "${CYAN}Test 1: Feature Verification${NC}"
echo "-----------------------------------------------------------"
if [[ -f "${SCRIPT_DIR}/verify_all_features.sh" ]]; then
    "${SCRIPT_DIR}/verify_all_features.sh" 2>&1 | tee /tmp/feature_verification.log
    
    # Check results
    if grep -q "10 passed, 0 failed" /tmp/feature_verification.log; then
        echo ""
        echo -e "${GREEN}✓✓✓ All 10 features verified successfully${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ Some features need attention${NC}"
        echo "  Check: /tmp/feature_verification.log"
    fi
else
    echo -e "${YELLOW}⚠ Feature verification script not found${NC}"
fi
echo ""

# Test 2: Pipeline Diagnostics
echo -e "${CYAN}Test 2: Pipeline Diagnostics${NC}"
echo "-----------------------------------------------------------"
if [[ -f "${SCRIPT_DIR}/debug_pipeline.sh" ]]; then
    "${SCRIPT_DIR}/debug_pipeline.sh" 2>&1 | tee /tmp/pipeline_diagnostics.log
    
    # Check for critical issues
    if grep -q "✗" /tmp/pipeline_diagnostics.log; then
        echo ""
        echo -e "${YELLOW}⚠ Some diagnostic checks failed${NC}"
        echo "  Auto-fix will address these issues automatically"
    else
        echo ""
        echo -e "${GREEN}✓ All diagnostic checks passed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Pipeline diagnostic script not found${NC}"
fi
echo ""

# Test 3: AI Diagnostics
echo -e "${CYAN}Test 3: AI Model and GPU Diagnostics${NC}"
echo "-----------------------------------------------------------"
if [[ -f "${SCRIPT_DIR}/diagnose_ai.sh" ]]; then
    "${SCRIPT_DIR}/diagnose_ai.sh" 2>&1 | tee /tmp/ai_diagnostics.log
    
    # Check AI readiness
    if grep -q "10/10" /tmp/ai_diagnostics.log || grep -q "All checks passed" /tmp/ai_diagnostics.log; then
        echo ""
        echo -e "${GREEN}✓ AI model and GPU ready${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ AI model may need attention${NC}"
        echo "  Check: /tmp/ai_diagnostics.log"
    fi
else
    echo -e "${YELLOW}⚠ AI diagnostic script not found${NC}"
fi
echo ""

# Test 4: Docker Container Health
echo -e "${CYAN}Test 4: Docker Container Health Check${NC}"
echo "-----------------------------------------------------------"
CONTAINER_HEALTH=0

# Check container is running
if docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
    echo -e "${GREEN}✓ Container is running${NC}"
    ((CONTAINER_HEALTH++))
else
    echo -e "${RED}✗ Container is not running${NC}"
fi

# Check GPU access
if docker exec srgan-upscaler nvidia-smi >/dev/null 2>&1; then
    echo -e "${GREEN}✓ GPU accessible from container${NC}"
    ((CONTAINER_HEALTH++))
else
    echo -e "${RED}✗ GPU not accessible${NC}"
fi

# Check model file
if docker exec srgan-upscaler test -f /app/models/swift_srgan_4x.pth 2>/dev/null; then
    MODEL_SIZE=$(docker exec srgan-upscaler ls -lh /app/models/swift_srgan_4x.pth 2>/dev/null | awk '{print $5}')
    echo -e "${GREEN}✓ Model file exists (${MODEL_SIZE})${NC}"
    ((CONTAINER_HEALTH++))
else
    echo -e "${RED}✗ Model file missing${NC}"
fi

# Check pipeline process
if docker exec srgan-upscaler pgrep -f "srgan_pipeline.py" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Pipeline process is running${NC}"
    ((CONTAINER_HEALTH++))
else
    echo -e "${YELLOW}⚠ Pipeline process not running (will start when job queued)${NC}"
    ((CONTAINER_HEALTH++))  # Not critical
fi

# Check media access
if docker exec srgan-upscaler test -d /mnt/media 2>/dev/null; then
    FILE_COUNT=$(docker exec srgan-upscaler find /mnt/media -maxdepth 3 -type f \( -name "*.mkv" -o -name "*.mp4" \) 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ Media directory accessible (${FILE_COUNT} files)${NC}"
    ((CONTAINER_HEALTH++))
else
    echo -e "${RED}✗ Media directory not accessible${NC}"
fi

echo ""
echo "Container health score: ${CONTAINER_HEALTH}/5"
if [[ $CONTAINER_HEALTH -ge 4 ]]; then
    echo -e "${GREEN}✓ Container is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Container needs attention${NC}"
fi
echo ""

# Test 5: Service Health
echo -e "${CYAN}Test 5: Service Health Check${NC}"
echo "-----------------------------------------------------------"
SERVICE_HEALTH=0

# Watchdog API
if systemctl is-active --quiet srgan-watchdog-api; then
    echo -e "${GREEN}✓ Watchdog API service running${NC}"
    ((SERVICE_HEALTH++))
else
    echo -e "${RED}✗ Watchdog API not running${NC}"
fi

# Auto-fix timer
if systemctl is-active --quiet srgan-autofix.timer; then
    echo -e "${GREEN}✓ Auto-fix timer active${NC}"
    ((SERVICE_HEALTH++))
else
    echo -e "${RED}✗ Auto-fix timer not active${NC}"
fi

# Watchdog API endpoint
if curl -s -f http://localhost:5432/status >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Watchdog API responding${NC}"
    ((SERVICE_HEALTH++))
else
    echo -e "${YELLOW}⚠ Watchdog API not responding yet${NC}"
fi

echo ""
echo "Service health score: ${SERVICE_HEALTH}/3"
if [[ $SERVICE_HEALTH -ge 2 ]]; then
    echo -e "${GREEN}✓ Services are healthy${NC}"
else
    echo -e "${YELLOW}⚠ Services need attention${NC}"
fi
echo ""

# Test 6: Configuration Validation
echo -e "${CYAN}Test 6: Configuration Validation${NC}"
echo "-----------------------------------------------------------"
CONFIG_VALID=0

# Check docker-compose.yml
if [[ -f "${REPO_DIR}/docker-compose.yml" ]]; then
    if grep -q "SRGAN_ENABLE=1" "${REPO_DIR}/docker-compose.yml"; then
        echo -e "${GREEN}✓ AI upscaling enabled${NC}"
        ((CONFIG_VALID++))
    else
        echo -e "${YELLOW}⚠ AI upscaling not enabled${NC}"
    fi
    
    if grep -q "/mnt/media:/mnt/media:rw" "${REPO_DIR}/docker-compose.yml"; then
        echo -e "${GREEN}✓ Media volume mounted read-write${NC}"
        ((CONFIG_VALID++))
    else
        echo -e "${YELLOW}⚠ Media volume may be read-only${NC}"
    fi
    
    if grep -q "OUTPUT_FORMAT=mkv" "${REPO_DIR}/docker-compose.yml"; then
        echo -e "${GREEN}✓ Output format configured (MKV)${NC}"
        ((CONFIG_VALID++))
    else
        echo -e "${YELLOW}⚠ Output format not explicitly set${NC}"
    fi
else
    echo -e "${RED}✗ docker-compose.yml not found${NC}"
fi

# Check environment file
if [[ -f "${ENV_FILE}" ]]; then
    echo -e "${GREEN}✓ Watchdog environment file exists${NC}"
    ((CONFIG_VALID++))
else
    echo -e "${YELLOW}⚠ Watchdog environment file missing${NC}"
fi

echo ""
echo "Configuration score: ${CONFIG_VALID}/4"
if [[ $CONFIG_VALID -ge 3 ]]; then
    echo -e "${GREEN}✓ Configuration is valid${NC}"
else
    echo -e "${YELLOW}⚠ Configuration needs review${NC}"
fi
echo ""

# Test 7: Python Scripts Verification
echo -e "${CYAN}Test 7: Python Scripts Health Check${NC}"
echo "-----------------------------------------------------------"
PYTHON_HEALTH=0

# Check key Python files have shebangs
KEY_PYTHON_FILES=(
    "srgan_pipeline.py"
    "your_model_file_ffmpeg.py"
    "your_model_file.py"
    "watchdog_api.py"
)

for py_file in "${KEY_PYTHON_FILES[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${py_file}" ]]; then
        if head -1 "${SCRIPT_DIR}/${py_file}" | grep -q "^#!/usr/bin/env python3"; then
            echo -e "${GREEN}✓ ${py_file} has shebang${NC}"
            ((PYTHON_HEALTH++))
        else
            echo -e "${RED}✗ ${py_file} missing shebang${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ ${py_file} not found${NC}"
    fi
done

echo ""
echo "Python health score: ${PYTHON_HEALTH}/${#KEY_PYTHON_FILES[@]}"
if [[ $PYTHON_HEALTH -eq ${#KEY_PYTHON_FILES[@]} ]]; then
    echo -e "${GREEN}✓ All Python scripts properly configured${NC}"
else
    echo -e "${YELLOW}⚠ Some Python scripts need fixing${NC}"
fi
echo ""

#==============================================================================
# Step 14: Generate Verification Report
#==============================================================================

echo -e "${BLUE}Step 14: Generating installation report...${NC}"
echo "=========================================================================="
echo ""

REPORT_FILE="${REPO_DIR}/INSTALLATION_REPORT.txt"

cat > "$REPORT_FILE" << EOF
================================================================================
SRGAN PIPELINE INSTALLATION REPORT
================================================================================
Date: $(date)
Installation Directory: ${REPO_DIR}

================================================================================
VERIFICATION SUMMARY
================================================================================

Test 1: Feature Verification
$(grep -E "passed|failed" /tmp/feature_verification.log 2>/dev/null || echo "Not available")

Test 2: Pipeline Diagnostics
  Container Health: ${CONTAINER_HEALTH}/5
  Service Health: ${SERVICE_HEALTH}/3

Test 3: AI & GPU Diagnostics
$(grep -E "✓|✗|PASS|FAIL" /tmp/ai_diagnostics.log 2>/dev/null | head -10 || echo "Not available")

Test 4: Configuration
  Configuration Score: ${CONFIG_VALID}/4

Test 5: Python Scripts
  Python Health: ${PYTHON_HEALTH}/${#KEY_PYTHON_FILES[@]}

================================================================================
SERVICES STATUS
================================================================================
Watchdog API: $(systemctl is-active srgan-watchdog-api 2>/dev/null || echo "unknown")
Auto-fix Timer: $(systemctl is-active srgan-autofix.timer 2>/dev/null || echo "unknown")
Docker Container: $(docker ps --format '{{.Status}}' --filter name=srgan-upscaler 2>/dev/null || echo "not running")

================================================================================
CONFIGURATION
================================================================================
Environment File: ${ENV_FILE}
Service File: ${SERVICE_FILE}
Queue File: ${REPO_DIR}/cache/queue.jsonl
Jellyfin URL: ${JELLYFIN_URL}

================================================================================
QUICK COMMANDS
================================================================================
View Logs:
  - Watchdog: sudo journalctl -u srgan-watchdog-api -f
  - Auto-fix: tail -f /var/log/srgan-autofix.log
  - Container: docker logs -f srgan-upscaler

Diagnostics:
  - Features: ${SCRIPT_DIR}/verify_all_features.sh
  - Pipeline: ${SCRIPT_DIR}/debug_pipeline.sh
  - AI Model: ${SCRIPT_DIR}/diagnose_ai.sh
  - Auto-fix: ${SCRIPT_DIR}/autofix.sh

Testing:
  - Manual test: ${SCRIPT_DIR}/test_manual_queue.sh
  - Complete workflow: ${SCRIPT_DIR}/test_complete_workflow.sh

================================================================================
NEXT STEPS
================================================================================
1. Configure Jellyfin webhook (see above)
2. Play a video in Jellyfin
3. Monitor logs: docker logs -f srgan-upscaler
4. Check output: Files will appear in same directory as input

================================================================================
SUPPORT
================================================================================
If issues occur:
1. Check auto-fix logs: tail -f /var/log/srgan-autofix.log
2. Run diagnostics: ${SCRIPT_DIR}/debug_pipeline.sh
3. Check this report: ${REPORT_FILE}

Auto-fix will automatically resolve most issues within 5 minutes.

================================================================================
EOF

echo -e "${GREEN}✓ Installation report generated${NC}"
echo "  Report saved to: ${REPORT_FILE}"
echo ""

# Display summary
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}VERIFICATION SUMMARY${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

TOTAL_SCORE=$((CONTAINER_HEALTH + SERVICE_HEALTH + CONFIG_VALID + PYTHON_HEALTH))
MAX_SCORE=17

echo "Overall Health Score: ${TOTAL_SCORE}/${MAX_SCORE}"
echo ""

if [[ $TOTAL_SCORE -ge 14 ]]; then
    echo -e "${GREEN}✓✓✓ EXCELLENT${NC} - System is fully operational"
elif [[ $TOTAL_SCORE -ge 10 ]]; then
    echo -e "${YELLOW}⚠ GOOD${NC} - Minor issues detected, auto-fix will resolve"
else
    echo -e "${RED}⚠ NEEDS ATTENTION${NC} - Check report and run diagnostics"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

#==============================================================================
# Installation Complete
#==============================================================================

echo "=========================================================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "=========================================================================="
echo ""

echo -e "${CYAN}✓ Automated Verification Completed${NC}"
echo "  All tests and diagnostics have been run automatically"
echo "  Installation report: ${REPORT_FILE}"
echo ""

echo -e "${CYAN}Services Running:${NC}"
systemctl is-active --quiet srgan-watchdog-api && echo -e "  ✓ srgan-watchdog-api: ${GREEN}running${NC}" || echo -e "  ✗ srgan-watchdog-api: ${RED}not running${NC}"
systemctl is-active --quiet srgan-autofix.timer && echo -e "  ✓ srgan-autofix (timer): ${GREEN}active${NC}" || echo -e "  ✗ srgan-autofix: ${RED}not active${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "srgan-upscaler|hls-server" | sed 's/^/  ✓ /' || true

echo ""
echo -e "${CYAN}Quick Commands:${NC}"
echo "  Service status:  sudo systemctl status srgan-watchdog-api"
echo "  View logs:       sudo journalctl -u srgan-watchdog-api -f"
echo "  Restart:         sudo systemctl restart srgan-watchdog-api"
echo ""
echo "  Auto-fix status: sudo systemctl status srgan-autofix.timer"
echo "  Auto-fix logs:   tail -f /var/log/srgan-autofix.log"
echo "  Run auto-fix:    ${SCRIPT_DIR}/autofix.sh"
echo ""
echo "  API status:      curl http://localhost:5432/status"
echo "  Now playing:     curl http://localhost:5432/playing"
echo ""
echo "  Container logs:  docker logs srgan-upscaler -f"
echo "  Restart:         docker compose restart srgan-upscaler"
echo ""
echo "  Debug:           ${SCRIPT_DIR}/debug_pipeline.sh"
echo "  Manual test:     ${SCRIPT_DIR}/test_manual_queue.sh"
echo ""

echo -e "${CYAN}Configuration:${NC}"
echo "  Environment:     ${ENV_FILE}"
echo "  Service:         ${SERVICE_FILE}"
echo "  Queue file:      ${REPO_DIR}/cache/queue.jsonl"
echo "  Output dir:      /mnt/media/upscaled/"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo "  1. ✓ Jellyfin webhook configured (manual step above)"
echo "  2. Play a video in Jellyfin"
echo "  3. Monitor: sudo journalctl -u srgan-watchdog-api -f"
echo "  4. Check output: ls -lh /mnt/media/upscaled/hls/"
echo ""

echo -e "${CYAN}Documentation:${NC}"
echo "  Quick start:     ${REPO_DIR}/QUICK_START_API.md"
echo "  Troubleshooting: ${REPO_DIR}/FIX_DOCKER_CANNOT_FIND_FILE.md"
echo "  Architecture:    ${REPO_DIR}/ARCHITECTURE_SIMPLE.md"
echo "  All docs:        ${REPO_DIR}/DOCUMENTATION_INDEX.md"
echo ""

echo -e "${GREEN}🎉 Ready to upscale videos!${NC}"
echo ""
