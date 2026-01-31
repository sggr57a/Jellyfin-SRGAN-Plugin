#!/bin/bash
# Simple script to start the SRGAN watchdog with all checks

set -e

echo "=========================================================================="
echo "SRGAN Upscaler Watchdog Startup"
echo "=========================================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python 3 not found${NC}"
    echo "Please install Python 3 first"
    exit 1
fi

# Check if Flask is installed
if ! python3 -c "import flask" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Flask not installed${NC}"
    echo "Installing Flask and requests..."
    pip3 install flask requests
    echo ""
fi

# Check if watchdog.py exists
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WATCHDOG_SCRIPT="$SCRIPT_DIR/watchdog.py"

if [ ! -f "$WATCHDOG_SCRIPT" ]; then
    echo -e "${RED}✗ watchdog.py not found at $WATCHDOG_SCRIPT${NC}"
    exit 1
fi

# Create cache directory
mkdir -p "$PROJECT_DIR/cache"

# Set default environment variables if not set
export UPSCALED_DIR=${UPSCALED_DIR:-"/data/upscaled"}
export SRGAN_QUEUE_FILE=${SRGAN_QUEUE_FILE:-"$PROJECT_DIR/cache/queue.jsonl"}

echo -e "${GREEN}✓ Prerequisites checked${NC}"
echo ""
echo "Configuration:"
echo "  Watchdog script: $WATCHDOG_SCRIPT"
echo "  Output directory: $UPSCALED_DIR"
echo "  Queue file: $SRGAN_QUEUE_FILE"
echo ""

# Check if watchdog is already running
if lsof -Pi :5000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo -e "${YELLOW}⚠ Port 5000 is already in use${NC}"
    echo "There may already be a watchdog running."
    echo ""
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if running in foreground or background
if [ "$1" = "-d" ] || [ "$1" = "--daemon" ]; then
    echo "Starting watchdog in background..."
    LOG_FILE="$PROJECT_DIR/watchdog.log"
    nohup python3 "$WATCHDOG_SCRIPT" > "$LOG_FILE" 2>&1 &
    PID=$!
    echo -e "${GREEN}✓ Watchdog started in background (PID: $PID)${NC}"
    echo "  Log file: $LOG_FILE"
    echo "  Monitor logs: tail -f $LOG_FILE"
    echo "  Stop watchdog: kill $PID"
    echo ""
    echo "Waiting for startup..."
    sleep 2

    # Test if it's running
    if curl -s http://localhost:5000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Watchdog is running and healthy${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Configure Jellyfin webhook: See WEBHOOK_SETUP.md"
        echo "  2. Test webhook: python3 scripts/test_webhook.py"
        echo "  3. Play a video in Jellyfin"
    else
        echo -e "${RED}✗ Watchdog may not have started correctly${NC}"
        echo "Check the log file: $LOG_FILE"
    fi
else
    echo "Starting watchdog in foreground..."
    echo "Press Ctrl+C to stop"
    echo ""
    echo "=========================================================================="
    echo ""

    # Run in foreground
    python3 "$WATCHDOG_SCRIPT"
fi
