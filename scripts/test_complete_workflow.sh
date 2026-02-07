#!/bin/bash
# End-to-End Test Script
# Tests the complete upscaling workflow from start to finish

set -e

echo "════════════════════════════════════════════════════════════════"
echo "END-TO-END UPSCALING TEST"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "This script will test the complete upscaling workflow:"
echo "  1. Find a sample video file"
echo "  2. Submit it for upscaling"
echo "  3. Monitor the processing"
echo "  4. Verify the output"
echo ""

# Check if running on server
if [ ! -d "/mnt/media" ]; then
    echo "⚠ Warning: /mnt/media not found"
    echo "This script should be run on the Jellyfin server."
    echo ""
fi

# Check if containers are running
echo "Step 1: Check container status"
echo "================================"
if docker ps | grep -q srgan-upscaler; then
    echo "✓ srgan-upscaler container is running"
else
    echo "✗ srgan-upscaler container is not running"
    echo ""
    echo "Start with: docker compose up -d"
    exit 1
fi
echo ""

# Find a test video
echo "Step 2: Find test video"
echo "======================="
if [ -d "/mnt/media/MOVIES" ]; then
    TEST_VIDEO=$(find /mnt/media/MOVIES -type f \( -name "*.mkv" -o -name "*.mp4" \) ! -name "*upscaled*" ! -name "*2160p*" -print -quit)
    
    if [ -n "$TEST_VIDEO" ]; then
        echo "✓ Found test video: $TEST_VIDEO"
        
        # Get video info
        echo ""
        echo "Video information:"
        docker exec srgan-upscaler ffprobe -v error -select_streams v:0 \
            -show_entries stream=width,height,codec_name \
            -of default=noprint_wrappers=1 "$TEST_VIDEO" 2>/dev/null | sed 's/^/  /'
    else
        echo "✗ No suitable test video found"
        echo ""
        echo "Looking for: MKV or MP4 files (not already upscaled)"
        exit 1
    fi
else
    echo "✗ /mnt/media/MOVIES not found"
    echo ""
    echo "Please provide a test video path:"
    read -p "Video path: " TEST_VIDEO
    
    if [ ! -f "$TEST_VIDEO" ]; then
        echo "✗ File not found: $TEST_VIDEO"
        exit 1
    fi
fi
echo ""

# Clear old queue
echo "Step 3: Clear old queue"
echo "======================="
if [ -f "./cache/queue.jsonl" ]; then
    QUEUE_SIZE=$(wc -l < ./cache/queue.jsonl)
    if [ $QUEUE_SIZE -gt 0 ]; then
        echo "Clearing $QUEUE_SIZE old jobs..."
        ./scripts/clear_queue.sh
    else
        echo "✓ Queue already empty"
    fi
else
    echo "✓ No queue file"
fi
echo ""

# Submit job via API
echo "Step 4: Submit upscaling job"
echo "============================="
echo ""
echo "⚠ MANUAL STEP REQUIRED:"
echo ""
echo "To test the complete workflow, you need to:"
echo "  1. Open Jellyfin in your browser"
echo "  2. Navigate to this video:"
echo "     $TEST_VIDEO"
echo "  3. Press play (even briefly)"
echo "  4. The webhook will automatically queue the upscaling job"
echo ""
echo "Alternatively, manually add to queue:"
echo ""
echo "cat >> ./cache/queue.jsonl << 'EOF'"
echo "{\"input\": \"$TEST_VIDEO\", \"output\": \"${TEST_VIDEO%.*}_upscaled.mkv\", \"streaming\": false}"
echo "EOF"
echo ""
read -p "Press Enter when job is queued..."
echo ""

# Monitor processing
echo "Step 5: Monitor processing"
echo "=========================="
echo ""
echo "Watching logs for AI upscaling activity..."
echo "(Press Ctrl+C to stop watching)"
echo ""

docker logs -f --tail 50 srgan-upscaler 2>&1 | while IFS= read -r line; do
    # Highlight key events
    case "$line" in
        *"AI Upscaling Job"*)
            echo ""
            echo "┌────────────────────────────────────────────────────────────────┐"
            echo "│ 🚀 JOB STARTED                                                  │"
            echo "└────────────────────────────────────────────────────────────────┘"
            ;;
        *"Input:"*)
            echo "  📥 $line"
            ;;
        *"Output:"*)
            echo "  📤 $line"
            ;;
        *"Loading AI model"*)
            echo "  🧠 Loading AI model..."
            ;;
        *"Model loaded"*)
            echo "  ✓ Model loaded"
            ;;
        *"Analyzing input"*)
            echo "  🔍 Analyzing video..."
            ;;
        *"Starting AI upscaling"*)
            echo "  ⚙️  Processing frames..."
            ;;
        *"Processed"*"frames"*)
            echo "  📊 $line"
            ;;
        *"AI upscaling complete"*)
            echo "  ✓ Processing complete"
            ;;
        *"VERIFICATION PASSED"*)
            echo ""
            echo "┌────────────────────────────────────────────────────────────────┐"
            echo "│ ✓✓✓ SUCCESS - VERIFICATION PASSED ✓✓✓                          │"
            echo "└────────────────────────────────────────────────────────────────┘"
            ;;
        *"AI UPSCALING SUCCESSFULLY COMPLETED"*)
            echo ""
            echo "╔════════════════════════════════════════════════════════════════╗"
            echo "║ 🎉 UPSCALING COMPLETE 🎉                                        ║"
            echo "╚════════════════════════════════════════════════════════════════╝"
            echo ""
            break
            ;;
        *"ERROR"*)
            echo "  ❌ ERROR: $line"
            ;;
        *)
            # Show other lines with dimmed appearance
            echo "  $line"
            ;;
    esac
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "TEST COMPLETE"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Check for the upscaled file in the same directory as the input:"
echo "  Original: $TEST_VIDEO"
echo "  Upscaled: (check for *_upscaled.mkv or *[2160p].mkv)"
echo ""
echo "Next steps:"
echo "  1. Verify file exists and plays correctly"
echo "  2. Check file has correct resolution tag in filename"
echo "  3. Confirm file is in same directory as input"
echo "  4. Verify file size is reasonable (larger than input)"
echo ""
