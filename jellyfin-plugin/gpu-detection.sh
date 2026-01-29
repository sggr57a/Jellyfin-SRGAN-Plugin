#!/bin/bash
# GPU Detection Script for NVIDIA GPUs
# This script checks for NVIDIA GPU presence and compatibility

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== NVIDIA GPU Detection ==="
echo ""

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}ERROR: nvidia-smi not found. NVIDIA drivers may not be installed.${NC}"
    exit 1
fi

# Check if NVIDIA GPU is present
if ! nvidia-smi &> /dev/null; then
    echo -e "${RED}ERROR: No NVIDIA GPU detected or drivers not properly configured.${NC}"
    exit 1
fi

# Get GPU information
GPU_INFO=$(nvidia-smi --query-gpu=name,compute_cap,driver_version,memory.total --format=csv,noheader,nounits)

# Track GPU count
GPU_COUNT=0
GPU_LIST=()

while IFS=, read -r name compute_cap driver_version memory; do
    GPU_COUNT=$((GPU_COUNT + 1))
    name=$(echo "$name" | xargs)
    compute_cap=$(echo "$compute_cap" | xargs)
    driver_version=$(echo "$driver_version" | xargs)
    memory=$(echo "$memory" | xargs)
    
    GPU_LIST+=("GPU $GPU_COUNT: $name (Compute: $compute_cap, Driver: $driver_version, Memory: ${memory}MB)")
    echo -e "${GREEN}✓${NC} $name detected"
    echo "  - Compute Capability: $compute_cap"
    echo "  - Driver Version: $driver_version"
    echo "  - Memory: ${memory}MB"
done <<< "$GPU_INFO"

echo ""

if [ "$GPU_COUNT" -gt 0 ]; then
    echo -e "${GREEN}SUCCESS: NVIDIA GPU(s) detected!${NC}"
    echo ""
    echo "GPUs available:"
    for gpu in "${GPU_LIST[@]}"; do
        echo "  - $gpu"
    done
    echo ""
    
    # Check CUDA availability
    if command -v nvcc &> /dev/null; then
        CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')
        echo -e "${GREEN}CUDA Version: $CUDA_VERSION${NC}"
    else
        echo -e "${YELLOW}CUDA toolkit not found in PATH (may still be available in Docker)${NC}"
    fi
    
    # Check Docker GPU access (if Docker is available)
    if command -v docker &> /dev/null; then
        echo ""
        echo "Testing Docker GPU access..."
        if docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
            echo -e "${GREEN}✓ Docker GPU access working${NC}"
        else
            echo -e "${YELLOW}⚠ Docker GPU access may not be configured${NC}"
        fi
    fi
    
    exit 0
else
    echo -e "${RED}ERROR: No NVIDIA GPU detected.${NC}"
    echo "This plugin requires an NVIDIA GPU for upscaling functionality."
    exit 1
fi
