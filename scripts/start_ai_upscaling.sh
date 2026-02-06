#!/bin/bash
# Quick Start Script for AI Upscaling
# This script ensures Docker is running and starts the container

set -e

echo "════════════════════════════════════════════════════════════════"
echo "AI UPSCALING - QUICK START"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Step 1: Check Docker
echo "Step 1: Checking Docker..."
echo "----------------------------"
if check_docker; then
    echo "✓ Docker is running"
else
    echo "✗ Docker is not running"
    echo ""
    echo "Starting Docker Desktop..."
    
    # Try to open Docker Desktop on macOS
    if [ "$(uname)" = "Darwin" ]; then
        open -a Docker 2>/dev/null || true
        echo "Please wait for Docker Desktop to start..."
        echo ""
        
        # Wait up to 60 seconds for Docker to start
        for i in {1..60}; do
            if check_docker; then
                echo "✓ Docker is now running"
                break
            fi
            echo -n "."
            sleep 1
        done
        echo ""
        
        if ! check_docker; then
            echo "✗ Docker failed to start"
            echo ""
            echo "Please manually start Docker Desktop and run this script again."
            exit 1
        fi
    else
        echo "Please start Docker manually and run this script again."
        exit 1
    fi
fi
echo ""

# Step 2: Create required directories
echo "Step 2: Creating directories..."
echo "--------------------------------"
mkdir -p cache upscaled models
echo "✓ Directories created"
echo ""

# Step 3: Check model file
echo "Step 3: Checking AI model..."
echo "-----------------------------"
if [ -f "models/swift_srgan_4x.pth" ]; then
    SIZE=$(stat -f%z "models/swift_srgan_4x.pth" 2>/dev/null || stat -c%s "models/swift_srgan_4x.pth" 2>/dev/null)
    echo "✓ Model file found: $(($SIZE / 1024))KB"
else
    echo "✗ Model file not found: models/swift_srgan_4x.pth"
    echo ""
    echo "Please ensure the model file is present before starting."
    exit 1
fi
echo ""

# Step 4: Check if container is already running
echo "Step 4: Checking container status..."
echo "-------------------------------------"
if docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
    echo "✓ Container is already running"
    
    # Ask if user wants to restart
    echo ""
    read -p "Do you want to restart the container? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping container..."
        docker stop srgan-upscaler >/dev/null 2>&1
        docker rm srgan-upscaler >/dev/null 2>&1
        echo "✓ Container stopped"
        NEED_START=1
    else
        NEED_START=0
    fi
else
    echo "Container is not running"
    NEED_START=1
fi
echo ""

# Step 5: Start container if needed
if [ "$NEED_START" = "1" ]; then
    echo "Step 5: Starting container..."
    echo "------------------------------"
    
    # Ask if user wants to rebuild
    read -p "Do you want to rebuild the image (recommended if code changed)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Building image (this may take a few minutes)..."
        docker compose build --no-cache
        echo "✓ Image built"
        echo ""
    fi
    
    echo "Starting container..."
    docker compose up -d
    
    # Wait for container to be ready
    echo "Waiting for container to initialize..."
    sleep 5
    
    if docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
        echo "✓ Container started successfully"
    else
        echo "✗ Container failed to start"
        echo ""
        echo "Check logs with: docker logs srgan-upscaler"
        exit 1
    fi
    echo ""
fi

# Step 6: Verify configuration
echo "Step 6: Verifying configuration..."
echo "------------------------------------"

echo -n "AI enabled: "
AI_ENABLED=$(docker exec srgan-upscaler printenv SRGAN_ENABLE 2>/dev/null || echo "ERROR")
if [ "$AI_ENABLED" = "1" ]; then
    echo "✓ Yes (SRGAN_ENABLE=1)"
else
    echo "✗ No (SRGAN_ENABLE=$AI_ENABLED)"
fi

echo -n "Encoder: "
ENCODER=$(docker exec srgan-upscaler printenv SRGAN_FFMPEG_ENCODER 2>/dev/null || echo "ERROR")
echo "$ENCODER"
if [ "$ENCODER" != "hevc_nvenc" ]; then
    echo "  ⚠ Expected: hevc_nvenc"
fi

echo -n "Model file: "
if docker exec srgan-upscaler test -f /app/models/swift_srgan_4x.pth 2>/dev/null; then
    echo "✓ Found"
else
    echo "✗ Not found"
fi

echo -n "GPU access: "
if docker exec srgan-upscaler nvidia-smi >/dev/null 2>&1; then
    echo "✓ Available"
else
    echo "✗ Not available (will use CPU - slower)"
fi

echo -n "NVENC: "
if docker exec srgan-upscaler ffmpeg -hide_banner -encoders 2>&1 | grep -q hevc_nvenc; then
    echo "✓ Available"
else
    echo "✗ Not available (will use CPU encoding)"
fi

echo ""

# Step 7: Show logs
echo "Step 7: Recent logs..."
echo "----------------------"
docker logs --tail 20 srgan-upscaler 2>&1 || echo "(no logs yet)"
echo ""

# Step 8: Instructions
echo "════════════════════════════════════════════════════════════════"
echo "CONTAINER IS READY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "To monitor logs in real-time:"
echo "  docker logs -f srgan-upscaler"
echo ""
echo "To run full diagnostic:"
echo "  ./scripts/diagnose_ai.sh"
echo ""
echo "To test with a video manually:"
echo "  1. Copy video to container:"
echo "     docker cp /path/to/video.mp4 srgan-upscaler:/tmp/test.mp4"
echo ""
echo "  2. Add job to queue:"
echo "     docker exec srgan-upscaler bash -c 'echo \"{\\\"input\\\":\\\"/tmp/test.mp4\\\",\\\"output\\\":\\\"/data/upscaled/test.mkv\\\"}\" >> /app/cache/queue.jsonl'"
echo ""
echo "  3. Watch processing:"
echo "     docker logs -f srgan-upscaler"
echo ""
echo "When processing, you should see:"
echo "  'Using FFmpeg-based AI upscaling (recommended)'"
echo "  'Loading AI model...'"
echo "  '✓ Model loaded'"
echo "  'Processed 30 frames...'"
echo ""
echo "Output files will appear in:"
echo "  ./upscaled/ directory on your host"
echo ""
