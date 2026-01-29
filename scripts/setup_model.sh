#!/usr/bin/env bash
# Setup script for SRGAN model file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
MODEL_DIR="${MODEL_DIR:-${PROJECT_DIR}/models}"
MODEL_URL="https://github.com/Koushik0901/Swift-SRGAN/releases/download/v0.1/swift_srgan_4x.pth.tar"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================================================="
echo "SRGAN Model Setup"
echo "=========================================================================="
echo ""

# Create models directory
mkdir -p "${MODEL_DIR}"
echo "Model directory: ${MODEL_DIR}"
echo ""

# Check for existing files
HAS_TAR=false
HAS_PTH=false

if [[ -f "${MODEL_DIR}/swift_srgan_4x.pth.tar" ]]; then
    HAS_TAR=true
    TAR_SIZE=$(du -h "${MODEL_DIR}/swift_srgan_4x.pth.tar" | cut -f1)
    echo -e "${YELLOW}Found:${NC} swift_srgan_4x.pth.tar (${TAR_SIZE})"
fi

if [[ -f "${MODEL_DIR}/swift_srgan_4x.pth" ]]; then
    HAS_PTH=true
    PTH_SIZE=$(du -h "${MODEL_DIR}/swift_srgan_4x.pth" | cut -f1)
    echo -e "${GREEN}Found:${NC} swift_srgan_4x.pth (${PTH_SIZE})"
fi

echo ""

# Handle different scenarios
if [[ "${HAS_PTH}" == true ]]; then
    echo -e "${GREEN}✓ Model file swift_srgan_4x.pth is ready to use${NC}"

    if [[ "${HAS_TAR}" == true ]]; then
        echo ""
        echo -e "${YELLOW}Note: Both .pth.tar and .pth exist${NC}"
        read -p "Remove the .pth.tar file? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm "${MODEL_DIR}/swift_srgan_4x.pth.tar"
            echo -e "${GREEN}✓ Removed swift_srgan_4x.pth.tar${NC}"
        fi
    fi

elif [[ "${HAS_TAR}" == true ]]; then
    echo -e "${BLUE}Renaming swift_srgan_4x.pth.tar to swift_srgan_4x.pth...${NC}"
    mv "${MODEL_DIR}/swift_srgan_4x.pth.tar" "${MODEL_DIR}/swift_srgan_4x.pth"
    echo -e "${GREEN}✓ Model file renamed successfully${NC}"

else
    echo -e "${RED}✗ Model file not found${NC}"
    echo ""
    echo "Options:"
    echo ""
    echo "1. Download automatically (requires wget or curl)"
    echo "2. Manual download instructions"
    echo "3. Exit"
    echo ""
    read -p "Choose an option (1-3): " -n 1 -r
    echo ""

    case $REPLY in
        1)
            echo ""
            echo "Downloading model file..."

            if command -v wget >/dev/null 2>&1; then
                wget -O "${MODEL_DIR}/swift_srgan_4x.pth.tar" "${MODEL_URL}"
                DOWNLOAD_SUCCESS=$?
            elif command -v curl >/dev/null 2>&1; then
                curl -L -o "${MODEL_DIR}/swift_srgan_4x.pth.tar" "${MODEL_URL}"
                DOWNLOAD_SUCCESS=$?
            else
                echo -e "${RED}✗ Neither wget nor curl found${NC}"
                echo "Please install wget or curl, then run this script again"
                exit 1
            fi

            if [[ $DOWNLOAD_SUCCESS -eq 0 ]] && [[ -f "${MODEL_DIR}/swift_srgan_4x.pth.tar" ]]; then
                echo -e "${GREEN}✓ Download complete${NC}"
                echo ""
                echo "Renaming to swift_srgan_4x.pth..."
                mv "${MODEL_DIR}/swift_srgan_4x.pth.tar" "${MODEL_DIR}/swift_srgan_4x.pth"
                echo -e "${GREEN}✓ Model file ready${NC}"
            else
                echo -e "${RED}✗ Download failed${NC}"
                exit 1
            fi
            ;;
        2)
            echo ""
            echo "=========================================================================="
            echo "Manual Download Instructions"
            echo "=========================================================================="
            echo ""
            echo "1. Download the model file:"
            echo "   ${MODEL_URL}"
            echo ""
            echo "2. Save to: ${MODEL_DIR}/"
            echo ""
            echo "3. Rename the file:"
            echo "   cd ${MODEL_DIR}"
            echo "   mv swift_srgan_4x.pth.tar swift_srgan_4x.pth"
            echo ""
            echo "4. Verify:"
            echo "   ls -lh ${MODEL_DIR}/swift_srgan_4x.pth"
            echo ""
            echo "Or run this script again after downloading the file."
            echo "=========================================================================="
            ;;
        3)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid option. Exiting."
            exit 1
            ;;
    esac
fi

echo ""
echo "=========================================================================="
echo "Setup Complete"
echo "=========================================================================="
echo ""
echo "Model file location: ${MODEL_DIR}/swift_srgan_4x.pth"
echo ""
echo "To use the model, set in docker-compose.yml:"
echo "  SRGAN_ENABLE=1"
echo "  SRGAN_MODEL_PATH=/app/models/swift_srgan_4x.pth"
echo ""
