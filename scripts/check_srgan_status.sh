#!/bin/bash
#
# Check SRGAN Model Status
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
echo "SRGAN Model Status Check"
echo "=========================================================================="
echo ""

# Check SRGAN_ENABLE setting
echo -e "${CYAN}1. Configuration${NC}"
echo ""

SRGAN_ENABLED=$(grep "SRGAN_ENABLE=" "${REPO_DIR}/docker-compose.yml" | head -1 | cut -d= -f2)

if [[ "$SRGAN_ENABLED" == "1" ]]; then
    echo -e "  SRGAN_ENABLE: ${GREEN}1 (AI Model Enabled)${NC}"
else
    echo -e "  SRGAN_ENABLE: ${YELLOW}0 (FFmpeg Fallback Only)${NC}"
fi

echo ""

# Check model file
echo -e "${CYAN}2. Model Weights${NC}"
echo ""

MODEL_PATH=$(grep "SRGAN_MODEL_PATH=" "${REPO_DIR}/docker-compose.yml" | head -1 | cut -d= -f2)
LOCAL_MODEL_PATH="${REPO_DIR}/models/swift_srgan_4x.pth"

if [[ -f "$LOCAL_MODEL_PATH" ]]; then
    MODEL_SIZE=$(ls -lh "$LOCAL_MODEL_PATH" | awk '{print $5}')
    echo -e "  Model file: ${GREEN}✓ Found${NC}"
    echo "  Location: $LOCAL_MODEL_PATH"
    echo "  Size: $MODEL_SIZE"
else
    echo -e "  Model file: ${RED}✗ Missing${NC}"
    echo "  Expected: $LOCAL_MODEL_PATH"
    echo "  Status: Not downloaded"
fi

echo ""

# Check PyTorch in container
echo -e "${CYAN}3. Dependencies (Container)${NC}"
echo ""

if docker ps | grep -q srgan-upscaler; then
    echo -e "  Container: ${GREEN}✓ Running${NC}"
    echo ""
    
    # Check PyTorch
    if docker compose exec -T srgan-upscaler python3 -c "import torch" 2>/dev/null; then
        TORCH_VERSION=$(docker compose exec -T srgan-upscaler python3 -c "import torch; print(torch.__version__)" 2>/dev/null | tr -d '\r')
        echo -e "  PyTorch: ${GREEN}✓ Installed${NC} (${TORCH_VERSION})"
        
        # Check CUDA
        if docker compose exec -T srgan-upscaler python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null | grep -q True; then
            echo -e "  CUDA: ${GREEN}✓ Available${NC}"
        else
            echo -e "  CUDA: ${YELLOW}⚠ Not Available${NC}"
        fi
    else
        echo -e "  PyTorch: ${RED}✗ Not Installed${NC}"
    fi
    
    # Check torchaudio
    if docker compose exec -T srgan-upscaler python3 -c "import torchaudio" 2>/dev/null; then
        TORCHAUDIO_VERSION=$(docker compose exec -T srgan-upscaler python3 -c "import torchaudio; print(torchaudio.__version__)" 2>/dev/null | tr -d '\r')
        echo -e "  torchaudio: ${GREEN}✓ Installed${NC} (${TORCHAUDIO_VERSION})"
    else
        echo -e "  torchaudio: ${RED}✗ Not Installed${NC}"
    fi
else
    echo -e "  Container: ${RED}✗ Not Running${NC}"
    echo "  Run: docker compose up -d"
fi

echo ""

# Current status
echo "=========================================================================="
echo -e "${CYAN}Current Status${NC}"
echo "=========================================================================="
echo ""

if [[ "$SRGAN_ENABLED" == "1" ]] && [[ -f "$LOCAL_MODEL_PATH" ]]; then
    echo -e "${GREEN}✅ SRGAN AI Model: READY${NC}"
    echo ""
    echo "Status: AI-powered super-resolution enabled"
    echo "Method: Deep learning neural network (Swift-SRGAN)"
    echo "Quality: High detail reconstruction"
    echo "Speed: Slower (3-10x vs FFmpeg)"
    echo ""
    echo "The container will use the AI model for upscaling."
elif [[ "$SRGAN_ENABLED" == "1" ]] && [[ ! -f "$LOCAL_MODEL_PATH" ]]; then
    echo -e "${YELLOW}⚠️  SRGAN Enabled But Model Missing${NC}"
    echo ""
    echo "Status: Will fall back to FFmpeg"
    echo "Issue: Model weights not found"
    echo ""
    echo "To fix:"
    echo "  ./scripts/setup_model.sh"
    echo "  # Or manually download swift_srgan_4x.pth to models/"
else
    echo -e "${BLUE}ℹ️  FFmpeg Lanczos Scaling: ACTIVE${NC}"
    echo ""
    echo "Status: Basic interpolation (no AI)"
    echo "Method: Mathematical upscaling (Lanczos)"
    echo "Quality: Smooth, good for clean sources"
    echo "Speed: Fast (real-time capable)"
    echo ""
    echo "The container is using FFmpeg-only upscaling."
fi

echo ""

# What's actually being used
echo "=========================================================================="
echo -e "${CYAN}What's Actually Running?${NC}"
echo "=========================================================================="
echo ""

if docker ps | grep -q srgan-upscaler; then
    echo "Checking recent logs..."
    echo ""
    
    # Check for model loading in logs
    if docker logs srgan-upscaler 2>&1 | grep -q "model\|SRGAN"; then
        echo -e "${GREEN}Found AI model activity in logs${NC}"
        docker logs srgan-upscaler 2>&1 | grep -i "model\|srgan" | tail -5 | sed 's/^/  /'
    else
        echo -e "${BLUE}No AI model activity (using FFmpeg)${NC}"
        docker logs srgan-upscaler 2>&1 | grep -i "streaming\|batch\|Starting" | tail -3 | sed 's/^/  /'
    fi
    
    echo ""
    
    # Check GPU usage
    if command -v nvidia-smi &> /dev/null; then
        echo "GPU Status:"
        nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null | grep -E "python|ffmpeg" | head -3 | sed 's/^/  /' || echo "  (No GPU processes)"
    fi
else
    echo -e "${RED}Container not running${NC}"
fi

echo ""

# Recommendations
echo "=========================================================================="
echo -e "${CYAN}Recommendations${NC}"
echo "=========================================================================="
echo ""

if [[ "$SRGAN_ENABLED" == "0" ]]; then
    echo "📌 Current Mode: Fast FFmpeg Scaling"
    echo ""
    echo "Good for:"
    echo "  ✓ Real-time streaming"
    echo "  ✓ Already high-quality sources (1080p+)"
    echo "  ✓ When speed is priority"
    echo ""
    echo "To enable AI model:"
    echo "  1. Download model: ./scripts/setup_model.sh"
    echo "  2. Edit docker-compose.yml: SRGAN_ENABLE=0 → SRGAN_ENABLE=1"
    echo "  3. Rebuild: docker compose build && docker compose up -d"
    echo ""
    echo "Read: cat SRGAN_MODEL_STATUS.md"
elif [[ ! -f "$LOCAL_MODEL_PATH" ]]; then
    echo "⚠️  Action Required: Download Model Weights"
    echo ""
    echo "You enabled SRGAN but the model file is missing."
    echo ""
    echo "Download now:"
    echo "  ./scripts/setup_model.sh"
    echo ""
    echo "Or disable AI model:"
    echo "  sed -i 's/SRGAN_ENABLE=1/SRGAN_ENABLE=0/' docker-compose.yml"
    echo "  docker compose restart"
else
    echo "✅ AI Model Active and Ready"
    echo ""
    echo "Status: Using deep learning super-resolution"
    echo "Note: Processing is slower but higher quality"
    echo ""
    echo "Monitor processing:"
    echo "  docker logs -f srgan-upscaler"
    echo "  watch -n 1 nvidia-smi"
    echo ""
    echo "To switch back to fast mode:"
    echo "  sed -i 's/SRGAN_ENABLE=1/SRGAN_ENABLE=0/' docker-compose.yml"
    echo "  docker compose restart"
fi

echo ""
