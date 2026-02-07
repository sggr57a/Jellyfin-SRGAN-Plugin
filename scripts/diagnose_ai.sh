#!/bin/bash
# Comprehensive AI Upscaling Diagnostic
# Run this to check if AI upscaling is properly configured

echo "════════════════════════════════════════════════════════════════"
echo "AI UPSCALING DIAGNOSTIC"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. Check if container is running
echo "1. Container Status"
echo "-------------------"
if docker ps | grep -q srgan-upscaler; then
    echo "✓ Container is running"
else
    echo "✗ Container is NOT running"
    echo "  Fix: docker compose up -d"
    exit 1
fi
echo ""

# 2. Check SRGAN_ENABLE
echo "2. SRGAN_ENABLE Setting"
echo "-----------------------"
SRGAN_ENABLE=$(docker exec srgan-upscaler printenv SRGAN_ENABLE 2>/dev/null)
if [ "$SRGAN_ENABLE" = "1" ]; then
    echo "✓ SRGAN_ENABLE=1 (AI enabled)"
else
    echo "✗ SRGAN_ENABLE=$SRGAN_ENABLE (should be 1)"
    echo "  Fix: Set SRGAN_ENABLE=1 in docker-compose.yml"
fi
echo ""

# 3. Check model file exists
echo "3. AI Model File"
echo "----------------"
if docker exec srgan-upscaler test -f /app/models/swift_srgan_4x.pth; then
    SIZE=$(docker exec srgan-upscaler stat -f%z /app/models/swift_srgan_4x.pth 2>/dev/null || docker exec srgan-upscaler stat -c%s /app/models/swift_srgan_4x.pth 2>/dev/null)
    echo "✓ Model file exists"
    echo "  Path: /app/models/swift_srgan_4x.pth"
    echo "  Size: $SIZE bytes (~$(($SIZE / 1024))KB)"
else
    echo "✗ Model file NOT found"
    echo "  Expected: /app/models/swift_srgan_4x.pth"
    echo "  Fix: Run ./scripts/setup_model.sh"
fi
echo ""

# 4. Check PyTorch and CUDA
echo "4. PyTorch & CUDA"
echo "-----------------"
docker exec srgan-upscaler python -c "
import torch
print(f'✓ PyTorch: {torch.__version__}')
print(f'✓ CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'✓ CUDA device: {torch.cuda.get_device_name(0)}')
    print(f'✓ CUDA version: {torch.version.cuda}')
" 2>/dev/null || echo "✗ PyTorch check failed"
echo ""

# 5. Check GPU access
echo "5. GPU Access"
echo "-------------"
if docker exec srgan-upscaler nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null; then
    echo "✓ GPU accessible from container"
else
    echo "✗ GPU NOT accessible"
    echo "  Fix: Check nvidia-container-toolkit installation"
fi
echo ""

# 6. Check FFmpeg and encoder
echo "6. FFmpeg & NVENC"
echo "-----------------"
if docker exec srgan-upscaler which ffmpeg >/dev/null 2>&1; then
    echo "✓ FFmpeg found"
    if docker exec srgan-upscaler ffmpeg -hide_banner -encoders 2>&1 | grep -q hevc_nvenc; then
        echo "✓ hevc_nvenc encoder available"
    else
        echo "⚠ hevc_nvenc NOT available (will use CPU encoding)"
    fi
else
    echo "✗ FFmpeg NOT found"
fi
echo ""

# 7. Check model module import
echo "7. AI Model Module"
echo "------------------"
docker exec srgan-upscaler python -c "
import sys
sys.path.insert(0, '/app/scripts')
try:
    import your_model_file_ffmpeg
    print('✓ FFmpeg-based AI module imports successfully')
except ImportError as e:
    print(f'✗ FFmpeg module import failed: {e}')
    try:
        import your_model_file
        print('✓ Torchaudio-based AI module imports (fallback)')
    except ImportError as e2:
        print(f'✗ Torchaudio module import failed: {e2}')
" 2>&1
echo ""

# 8. Check queue file
echo "8. Job Queue"
echo "------------"
# Check if container is accessible first
if ! docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
    echo "⚠ Container not running - cannot check queue file"
    echo "  Fix: docker compose up -d"
elif docker exec srgan-upscaler test -f /app/cache/queue.jsonl 2>/dev/null; then
    LINES=$(docker exec srgan-upscaler wc -l < /app/cache/queue.jsonl 2>/dev/null | tr -d ' \r' || echo "0")
    echo "✓ Queue file exists"
    echo "  Pending jobs: $LINES"
    if [ "$LINES" -gt "0" ]; then
        echo "  Note: Clear old jobs with: ./scripts/clear_queue.sh"
    fi
else
    # Queue file doesn't exist yet - this is OK
    echo "⚠ Queue file not found (will be created on first job)"
    # Check if cache directory exists
    if ! docker exec srgan-upscaler test -d /app/cache 2>/dev/null; then
        echo "  Creating cache directory..."
        docker exec srgan-upscaler mkdir -p /app/cache 2>/dev/null || echo "  Could not create directory"
    fi
fi
echo ""

# 9. Check recent logs for AI activity
echo "9. Recent AI Activity (last 50 lines)"
echo "--------------------------------------"
docker logs --tail 50 srgan-upscaler 2>&1 | grep -E "(AI|SRGAN|Model|GPU|cuda|Using FFmpeg-based|Configuration:|✓)" | head -20 || echo "No recent AI activity in logs"
echo ""

# 10. Configuration summary
echo "10. Current Configuration"
echo "-------------------------"
docker exec srgan-upscaler printenv | grep "^SRGAN_" | sort
echo ""

# Summary
echo "════════════════════════════════════════════════════════════════"
echo "DIAGNOSTIC SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "If all checks show ✓, AI upscaling should work."
echo ""
echo "Common Issues:"
echo "  • SRGAN_ENABLE=0 → Set to 1 in docker-compose.yml"
echo "  • Model file missing → Run ./scripts/setup_model.sh"
echo "  • GPU not accessible → Check nvidia-container-toolkit"
echo "  • Old .ts jobs in queue → Run ./scripts/clear_queue.sh"
echo ""
echo "To test upscaling:"
echo "  1. Clear queue: ./scripts/clear_queue.sh"
echo "  2. Play a video in Jellyfin"
echo "  3. Watch logs: docker logs -f srgan-upscaler"
echo ""
echo "Expected log output:"
echo "  'Using FFmpeg-based AI upscaling (recommended)'"
echo "  'Configuration: Model: /app/models/swift_srgan_4x.pth'"
echo "  'Loading AI model...'"
echo "  '✓ Model loaded'"
echo "  'Processed X frames...'"
echo ""
