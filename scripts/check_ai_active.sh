#!/bin/bash
#
# Check if AI Upscaling is Active
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=========================================================================="
echo "AI Upscaling Status Check"
echo "=========================================================================="
echo ""

# Check if container is running
if ! docker ps | grep -q srgan-upscaler; then
    echo -e "${RED}✗ Container not running${NC}"
    echo ""
    echo "Start it with:"
    echo "  docker compose up -d"
    exit 1
fi

echo -e "${GREEN}✓ Container is running${NC}"
echo ""

# Check configuration
echo "=========================================================================="
echo -e "${CYAN}1. Configuration Check${NC}"
echo "=========================================================================="
echo ""

SRGAN_ENABLE=$(docker compose exec -T srgan-upscaler printenv SRGAN_ENABLE 2>/dev/null || echo "not set")

if [[ "$SRGAN_ENABLE" == "1" ]]; then
    echo -e "${GREEN}✓ SRGAN_ENABLE=1 (AI model enabled)${NC}"
else
    echo -e "${YELLOW}⚠ SRGAN_ENABLE=$SRGAN_ENABLE (AI model DISABLED)${NC}"
    echo ""
    echo "AI model is not enabled. To enable:"
    echo "  1. Edit docker-compose.yml"
    echo "  2. Set SRGAN_ENABLE=1"
    echo "  3. Restart: docker compose restart"
    echo ""
fi

echo ""

# Check model file
echo "=========================================================================="
echo -e "${CYAN}2. Model File Check${NC}"
echo "=========================================================================="
echo ""

if docker compose exec -T srgan-upscaler test -f /app/models/swift_srgan_4x.pth 2>/dev/null; then
    MODEL_SIZE=$(docker compose exec -T srgan-upscaler du -h /app/models/swift_srgan_4x.pth 2>/dev/null | awk '{print $1}')
    echo -e "${GREEN}✓ Model file exists${NC} (${MODEL_SIZE})"
else
    echo -e "${RED}✗ Model file NOT found${NC}"
    echo ""
    echo "Download model with:"
    echo "  ./scripts/setup_model.sh"
    echo ""
fi

echo ""

# Check logs for AI activity
echo "=========================================================================="
echo -e "${CYAN}3. Recent Log Analysis${NC}"
echo "=========================================================================="
echo ""

LOGS=$(docker logs srgan-upscaler 2>&1 | tail -100)

# Check for AI model initialization
if echo "$LOGS" | grep -q "AI Upscaling Configuration"; then
    echo -e "${GREEN}✓ AI model initialization found in logs${NC}"
    echo ""
    echo "AI Configuration:"
    echo "$LOGS" | grep -A 6 "AI Upscaling Configuration" | tail -7 | sed 's/^/  /'
    echo ""
elif echo "$LOGS" | grep -q "Loading SRGAN model"; then
    echo -e "${GREEN}✓ SRGAN model loading detected${NC}"
    echo ""
    echo "$LOGS" | grep -i "model\|srgan" | tail -5 | sed 's/^/  /'
    echo ""
elif echo "$LOGS" | grep -q "Using streaming mode\|Using batch mode"; then
    echo -e "${YELLOW}⚠ Using FFmpeg mode (no AI detected)${NC}"
    echo ""
    echo "Recent processing:"
    echo "$LOGS" | grep -E "Using|Starting" | tail -5 | sed 's/^/  /'
    echo ""
else
    echo -e "${YELLOW}⚠ No processing activity in recent logs${NC}"
    echo ""
fi

# Check GPU usage
echo "=========================================================================="
echo -e "${CYAN}4. GPU Usage Check${NC}"
echo "=========================================================================="
echo ""

if command -v nvidia-smi >/dev/null 2>&1; then
    # Check for Python process (AI model uses Python)
    GPU_PYTHON=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null | grep python)
    
    # Check for FFmpeg process
    GPU_FFMPEG=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null | grep ffmpeg)
    
    if [[ -n "$GPU_PYTHON" ]]; then
        echo -e "${GREEN}✓ Python process using GPU (AI model active)${NC}"
        echo ""
        echo "GPU processes:"
        echo "$GPU_PYTHON" | sed 's/^/  /'
        echo ""
        
        # High VRAM usage = AI model
        VRAM=$(echo "$GPU_PYTHON" | awk '{print $3}' | head -1)
        if [[ -n "$VRAM" ]]; then
            VRAM_NUM=$(echo "$VRAM" | sed 's/[^0-9]//g')
            if [[ $VRAM_NUM -gt 2000 ]]; then
                echo -e "${GREEN}✓ High VRAM usage (${VRAM}) = AI model likely active${NC}"
            else
                echo -e "${YELLOW}⚠ Low VRAM usage (${VRAM}) = May be FFmpeg only${NC}"
            fi
        fi
    elif [[ -n "$GPU_FFMPEG" ]]; then
        echo -e "${YELLOW}⚠ Only FFmpeg using GPU (AI model not active)${NC}"
        echo ""
        echo "GPU processes:"
        echo "$GPU_FFMPEG" | sed 's/^/  /'
    else
        echo -e "${YELLOW}⚠ No GPU processes detected${NC}"
        echo ""
        echo "Either:"
        echo "  - No video processing currently active"
        echo "  - GPU not accessible to container"
    fi
    
    echo ""
    
    # Show full GPU status
    echo "Current GPU status:"
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠ nvidia-smi not available${NC}"
fi

echo ""

# Summary
echo "=========================================================================="
echo -e "${CYAN}Summary${NC}"
echo "=========================================================================="
echo ""

AI_ACTIVE=false

# Determine if AI is active
if [[ "$SRGAN_ENABLE" == "1" ]] && docker compose exec -T srgan-upscaler test -f /app/models/swift_srgan_4x.pth 2>/dev/null; then
    if echo "$LOGS" | grep -q "AI Upscaling Configuration"; then
        AI_ACTIVE=true
    fi
fi

if [[ "$AI_ACTIVE" == "true" ]]; then
    echo -e "${GREEN}✅ AI UPSCALING IS ACTIVE${NC}"
    echo ""
    echo "Status:"
    echo "  • Configuration: SRGAN enabled"
    echo "  • Model: Loaded"
    echo "  • Mode: AI neural network upscaling"
    echo ""
    echo "What's happening:"
    echo "  1. Frames decoded from video"
    echo "  2. Denoised (if enabled)"
    echo "  3. Upscaled by SRGAN AI model"
    echo "  4. Encoded with NVENC"
    echo ""
else
    echo -e "${YELLOW}⚠️  FFmpeg MODE (Not using AI)${NC}"
    echo ""
    echo "Reasons:"
    if [[ "$SRGAN_ENABLE" != "1" ]]; then
        echo "  • SRGAN_ENABLE is not 1"
    fi
    if ! docker compose exec -T srgan-upscaler test -f /app/models/swift_srgan_4x.pth 2>/dev/null; then
        echo "  • Model file missing"
    fi
    if ! echo "$LOGS" | grep -q "AI Upscaling"; then
        echo "  • No AI activity in logs"
    fi
    echo ""
    echo "Current mode:"
    echo "  • Using FFmpeg Lanczos scaling"
    echo "  • Fast but lower quality"
    echo ""
fi

echo "=========================================================================="
echo ""

echo "Monitor in real-time:"
echo "  docker logs -f srgan-upscaler"
echo ""
echo "Watch GPU:"
echo "  watch -n 1 nvidia-smi"
echo ""
