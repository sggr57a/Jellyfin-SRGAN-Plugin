#!/bin/bash
# Manual Test - Queue a job and watch it process

echo "════════════════════════════════════════════════════════════════"
echo "MANUAL PIPELINE TEST"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
    echo "✗ Container not running"
    echo "Start with: docker compose up -d"
    exit 1
fi

# Find a test file
TEST_FILE=""
if [ -d "/mnt/media/MOVIES" ]; then
    TEST_FILE=$(find /mnt/media/MOVIES -type f \( -name "*.mkv" -o -name "*.mp4" \) ! -name "*upscaled*" ! -name "*2160p*" -print -quit 2>/dev/null)
fi

if [ -z "$TEST_FILE" ]; then
    echo "No test file found automatically."
    echo ""
    read -p "Enter path to test video: " TEST_FILE
fi

if [ ! -f "$TEST_FILE" ]; then
    echo "✗ File not found: $TEST_FILE"
    exit 1
fi

echo "Test file: $TEST_FILE"
echo ""

# Get file info
echo "File information:"
docker exec srgan-upscaler ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,codec_name \
    -of default=noprint_wrappers=1 "$TEST_FILE" 2>/dev/null | sed 's/^/  /'
echo ""

# Create output path
INPUT_DIR=$(dirname "$TEST_FILE")
INPUT_BASE=$(basename "$TEST_FILE")
OUTPUT_FILE="${INPUT_DIR}/${INPUT_BASE%.*}_test_upscale.mkv"

echo "Output will be: $OUTPUT_FILE"
echo ""

# Clear old queue
if [ -f "./cache/queue.jsonl" ]; then
    echo "Backing up and clearing queue..."
    cp ./cache/queue.jsonl "./cache/queue.jsonl.backup.$(date +%s)"
    > ./cache/queue.jsonl
    echo "✓ Queue cleared"
    echo ""
fi

# Queue the job
echo "Queueing test job..."
mkdir -p ./cache
cat >> ./cache/queue.jsonl << EOF
{"input": "$TEST_FILE", "output": "$OUTPUT_FILE", "streaming": false}
EOF
echo "✓ Job queued"
echo ""

# Show queue
echo "Queue contents:"
cat ./cache/queue.jsonl | sed 's/^/  /'
echo ""

# Watch logs
echo "════════════════════════════════════════════════════════════════"
echo "WATCHING CONTAINER LOGS"
echo "════════════════════════════════════════════════════════════════"
echo "Press Ctrl+C to stop watching"
echo ""
sleep 2

# Monitor with highlighting
docker logs -f --tail 0 srgan-upscaler 2>&1 | while IFS= read -r line; do
    case "$line" in
        *"AI Upscaling Job"*)
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🚀 JOB STARTED"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;
        *"Input:"*)
            echo "📥 $line"
            ;;
        *"Output:"*)
            echo "📤 $line"
            ;;
        *"Loading AI model"*|*"Model loaded"*)
            echo "🧠 $line"
            ;;
        *"Analyzing input"*)
            echo "🔍 $line"
            ;;
        *"Starting AI upscaling"*)
            echo "⚙️  $line"
            ;;
        *"Processed"*"frames"*)
            # Only show progress every few lines
            if [ $((RANDOM % 3)) -eq 0 ]; then
                echo "📊 $line"
            fi
            ;;
        *"AI upscaling complete"*)
            echo "✅ $line"
            ;;
        *"VERIFICATION PASSED"*)
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✓✓✓ VERIFICATION PASSED ✓✓✓"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;
        *"AI UPSCALING SUCCESSFULLY COMPLETED"*)
            echo ""
            echo "╔════════════════════════════════════════════════════════════════╗"
            echo "║                     🎉 SUCCESS 🎉                               ║"
            echo "╚════════════════════════════════════════════════════════════════╝"
            echo ""
            echo "Output file: $OUTPUT_FILE"
            echo ""
            # Exit after success
            sleep 2
            exit 0
            ;;
        *"ERROR"*|*"Error"*)
            echo "❌ ERROR: $line"
            ;;
        *"WARNING"*)
            echo "⚠️  WARNING: $line"
            ;;
        *"Using FFmpeg-based AI upscaling"*)
            echo "✅ $line"
            ;;
        *"Using torchaudio.io-based AI upscaling"*)
            echo "⚠️  $line (FFmpeg version preferred)"
            ;;
        *)
            # Show other lines dimmed
            if [[ ! -z "$line" ]]; then
                echo "  $line"
            fi
            ;;
    esac
done
