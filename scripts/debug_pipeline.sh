#!/bin/bash
# Comprehensive Pipeline Debugging Script
# Checks all aspects of the upscaling pipeline

echo "════════════════════════════════════════════════════════════════"
echo "PIPELINE DEBUGGING - COMPREHENSIVE CHECK"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check 1: Container Status
echo "1. Container Status"
echo "==================="
if docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
    echo "✓ srgan-upscaler container is running"
    
    # Get container uptime
    UPTIME=$(docker ps --format '{{.Status}}' --filter name=srgan-upscaler)
    echo "  Status: $UPTIME"
else
    echo "✗ srgan-upscaler container is NOT running"
    echo ""
    echo "START CONTAINER:"
    echo "  docker compose up -d"
    exit 1
fi
echo ""

# Check 2: Pipeline Process
echo "2. Pipeline Process"
echo "==================="
if docker exec srgan-upscaler pgrep -f "srgan_pipeline.py" > /dev/null 2>&1; then
    PID=$(docker exec srgan-upscaler pgrep -f "srgan_pipeline.py")
    echo "✓ Pipeline process is running (PID: $PID)"
else
    echo "✗ Pipeline process is NOT running"
    echo ""
    echo "CHECK CONTAINER LOGS:"
    echo "  docker logs srgan-upscaler --tail 50"
    echo ""
    echo "POSSIBLE ISSUES:"
    echo "  - Pipeline crashed on startup"
    echo "  - Python import errors"
    echo "  - Model file missing"
fi
echo ""

# Check 3: Queue File
echo "3. Queue File"
echo "============="
if [ -f "./cache/queue.jsonl" ]; then
    QUEUE_SIZE=$(cat ./cache/queue.jsonl 2>/dev/null | wc -l | tr -d ' \r' || echo "0")
    # Ensure QUEUE_SIZE is a valid number
    if [[ ! "$QUEUE_SIZE" =~ ^[0-9]+$ ]]; then
        QUEUE_SIZE="0"
    fi
    echo "✓ Queue file exists"
    echo "  Jobs in queue: $QUEUE_SIZE"
    
    if [[ "$QUEUE_SIZE" -gt 0 ]] 2>/dev/null; then
        echo ""
        echo "  Recent jobs:"
        tail -3 ./cache/queue.jsonl | while read -r line; do
            echo "    - $line"
        done
    fi
else
    echo "⚠ Queue file does not exist: ./cache/queue.jsonl"
    echo "  This means no jobs have been queued yet"
fi
echo ""

# Check 4: Watchdog API Status
echo "4. Watchdog API Status"
echo "======================"
if systemctl is-active --quiet srgan-watchdog-api 2>/dev/null; then
    echo "✓ Watchdog API service is running"
    
    # Check recent activity
    LAST_LOG=$(journalctl -u srgan-watchdog-api -n 1 --no-pager 2>/dev/null | tail -1)
    if [ -n "$LAST_LOG" ]; then
        echo "  Last log: $LAST_LOG"
    fi
else
    echo "⚠ Watchdog API service status unknown or not running"
    echo ""
    echo "CHECK STATUS:"
    echo "  systemctl status srgan-watchdog-api"
    echo ""
    echo "VIEW LOGS:"
    echo "  journalctl -u srgan-watchdog-api -n 50"
fi
echo ""

# Check 5: GPU Access
echo "5. GPU Access"
echo "============="
if docker exec srgan-upscaler nvidia-smi > /dev/null 2>&1; then
    echo "✓ GPU is accessible from container"
    
    # Get GPU info
    GPU_INFO=$(docker exec srgan-upscaler nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null)
    echo "  GPU: $GPU_INFO"
else
    echo "✗ GPU is NOT accessible from container"
    echo ""
    echo "FIX:"
    echo "  1. Check nvidia-docker is installed"
    echo "  2. Restart Docker: systemctl restart docker"
    echo "  3. Recreate container: docker compose down && docker compose up -d"
fi
echo ""

# Check 6: Model File
echo "6. Model File"
echo "============="
if docker exec srgan-upscaler test -f /app/models/swift_srgan_4x.pth 2>/dev/null; then
    MODEL_SIZE=$(docker exec srgan-upscaler ls -lh /app/models/swift_srgan_4x.pth 2>/dev/null | awk '{print $5}')
    echo "✓ Model file exists"
    echo "  Size: $MODEL_SIZE"
else
    echo "✗ Model file is MISSING"
    echo ""
    echo "DOWNLOAD MODEL:"
    echo "  ./scripts/setup_model.sh"
    exit 1
fi
echo ""

# Check 7: Environment Variables
echo "7. Environment Variables"
echo "========================"
SRGAN_ENABLE=$(docker exec srgan-upscaler printenv SRGAN_ENABLE 2>/dev/null || echo "NOT SET")
SRGAN_MODEL=$(docker exec srgan-upscaler printenv SRGAN_MODEL_PATH 2>/dev/null || echo "NOT SET")
SRGAN_DEVICE=$(docker exec srgan-upscaler printenv SRGAN_DEVICE 2>/dev/null || echo "NOT SET")
ENCODER=$(docker exec srgan-upscaler printenv SRGAN_FFMPEG_ENCODER 2>/dev/null || echo "NOT SET")

echo "  SRGAN_ENABLE: $SRGAN_ENABLE"
echo "  SRGAN_MODEL_PATH: $SRGAN_MODEL"
echo "  SRGAN_DEVICE: $SRGAN_DEVICE"
echo "  SRGAN_FFMPEG_ENCODER: $ENCODER"

if [ "$SRGAN_ENABLE" != "1" ]; then
    echo ""
    echo "✗ AI upscaling is DISABLED"
    echo ""
    echo "FIX: Edit docker-compose.yml and set SRGAN_ENABLE=1"
    exit 1
fi
echo ""

# Check 8: Recent Container Logs
echo "8. Recent Container Logs (Last 20 lines)"
echo "========================================="
docker logs srgan-upscaler --tail 20 2>&1 | while IFS= read -r line; do
    case "$line" in
        *"ERROR"*|*"Error"*|*"error"*)
            echo "  ❌ $line"
            ;;
        *"WARNING"*|*"Warning"*)
            echo "  ⚠️  $line"
            ;;
        *"SUCCESS"*|*"✓"*)
            echo "  ✅ $line"
            ;;
        *)
            echo "  $line"
            ;;
    esac
done
echo ""

# Check 9: Test AI Import in Container
echo "9. Test AI Module Import"
echo "========================"
AI_TEST=$(docker exec srgan-upscaler python3 -c "
import sys
sys.path.insert(0, '/app/scripts')
try:
    import your_model_file_ffmpeg
    print('✓ FFmpeg-based AI module imports successfully')
except Exception as e:
    print(f'✗ FFmpeg-based AI module error: {e}')
    
try:
    import torch
    print(f'✓ PyTorch {torch.__version__} available')
    print(f'✓ CUDA available: {torch.cuda.is_available()}')
    if torch.cuda.is_available():
        print(f'✓ CUDA device: {torch.cuda.get_device_name(0)}')
except Exception as e:
    print(f'✗ PyTorch error: {e}')
" 2>&1)
echo "$AI_TEST" | sed 's/^/  /'
echo ""

# Check 10: Volume Mount Test
echo "10. Volume Mount Test"
echo "====================="
if docker exec srgan-upscaler test -d /mnt/media 2>/dev/null; then
    FILE_COUNT=$(docker exec srgan-upscaler find /mnt/media -type f \( -name "*.mkv" -o -name "*.mp4" \) 2>/dev/null | wc -l)
    echo "✓ /mnt/media is mounted"
    echo "  Video files accessible: $FILE_COUNT"
    
    # Test write permission
    if docker exec srgan-upscaler touch /mnt/media/.write_test 2>/dev/null; then
        docker exec srgan-upscaler rm /mnt/media/.write_test 2>/dev/null
        echo "✓ Write permission: YES"
    else
        echo "✗ Write permission: NO"
        echo ""
        echo "FIX: Volume must be mounted read-write"
        echo "  docker-compose.yml: /mnt/media:/mnt/media:rw"
    fi
else
    echo "✗ /mnt/media is NOT mounted"
    echo ""
    echo "FIX: Check docker-compose.yml volume mounts"
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════════════"
echo "DIAGNOSTIC SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo ""
echo "1. If pipeline is NOT processing jobs:"
echo "   a. Check recent logs: docker logs -f srgan-upscaler"
echo "   b. Look for import errors or crashes"
echo "   c. Verify model file is valid"
echo ""
echo "2. If no jobs are being queued:"
echo "   a. Check watchdog API: journalctl -u srgan-watchdog-api -f"
echo "   b. Test webhook: Play video in Jellyfin"
echo "   c. Check queue file: cat ./cache/queue.jsonl"
echo ""
echo "3. To manually test AI upscaling:"
echo "   docker exec -it srgan-upscaler python3 /app/scripts/srgan_pipeline.py \\"
echo "     --input /mnt/media/path/to/video.mkv \\"
echo "     --output /mnt/media/path/to/video_upscaled.mkv"
echo ""
echo "════════════════════════════════════════════════════════════════"
