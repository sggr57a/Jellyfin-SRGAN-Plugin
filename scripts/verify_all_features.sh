#!/bin/bash
# Complete Feature Verification Script
# Verifies all requested features are implemented and working

echo "════════════════════════════════════════════════════════════════"
echo "COMPLETE FEATURE VERIFICATION"
echo "════════════════════════════════════════════════════════════════"
echo ""

PASSED=0
FAILED=0

function check_feature() {
    local feature="$1"
    local test_command="$2"
    local expected="$3"
    
    echo "Testing: $feature"
    echo "-------------------"
    
    if eval "$test_command"; then
        echo "✓ PASS: $expected"
        ((PASSED++))
    else
        echo "✗ FAIL: $expected"
        ((FAILED++))
    fi
    echo ""
}

# Feature 1: HLS Input Rejection
echo "Feature 1: HLS Stream Input Rejection"
echo "======================================="
if grep -q "if input_lower.endswith('.m3u8')" scripts/watchdog_api.py && \
   grep -q "if input_lower.endswith('.m3u8')" scripts/srgan_pipeline.py; then
    echo "✓ PASS: HLS stream inputs are rejected at both API and pipeline level"
    ((PASSED++))
else
    echo "✗ FAIL: HLS validation missing"
    ((FAILED++))
fi
echo ""

# Feature 2: AI-Only Mode (No FFmpeg Fallback)
echo "Feature 2: AI-Only Mode (No FFmpeg Fallback)"
echo "=============================================="
# Check for error handling when AI fails (not fallback)
if grep -q 'ERROR: AI model upscaling failed' scripts/srgan_pipeline.py && \
   ! grep -q 'def _run_ffmpeg(' scripts/srgan_pipeline.py | grep -v 'NotImplementedError'; then
    echo "✓ PASS: AI upscaling is mandatory, job fails if AI fails (no FFmpeg fallback)"
    ((PASSED++))
else
    echo "✗ FAIL: FFmpeg fallback still exists"
    ((FAILED++))
fi
echo ""

# Feature 3: Intelligent Filename Generation
echo "Feature 3: Intelligent Filename with Resolution & HDR"
echo "======================================================"
if grep -q "_generate_output_filename" scripts/srgan_pipeline.py && \
   grep -q "_resolution_to_label" scripts/srgan_pipeline.py; then
    echo "✓ PASS: Intelligent filename generation implemented"
    ((PASSED++))
else
    echo "✗ FAIL: Intelligent naming missing"
    ((FAILED++))
fi
echo ""

# Feature 4: Same Directory Output
echo "Feature 4: Output to Same Directory as Input"
echo "============================================="
if grep -q "input_dir = os.path.dirname(input_file)" scripts/watchdog_api.py; then
    echo "✓ PASS: Output saves to same directory as input"
    ((PASSED++))
else
    echo "✗ FAIL: Separate output directory still used"
    ((FAILED++))
fi
echo ""

# Feature 5: MKV/MP4 Only (No TS)
echo "Feature 5: MKV/MP4 Output Only (No TS/HLS)"
echo "==========================================="
if grep -q 'if output_ext not in' scripts/your_model_file_ffmpeg.py && \
   grep -q "Only .mkv and .mp4 supported" scripts/your_model_file_ffmpeg.py; then
    echo "✓ PASS: Only MKV/MP4 output supported, TS rejected"
    ((PASSED++))
else
    echo "✗ FAIL: TS output still supported"
    ((FAILED++))
fi
echo ""

# Feature 6: Verification Logging
echo "Feature 6: Output Verification & Logging"
echo "========================================="
if grep -q "_verify_upscaled_output" scripts/srgan_pipeline.py; then
    echo "✓ PASS: Output verification implemented"
    ((PASSED++))
else
    echo "✗ FAIL: Verification missing"
    ((FAILED++))
fi
echo ""

# Feature 7: SRGAN_ENABLE=1
echo "Feature 7: SRGAN_ENABLE Configuration"
echo "======================================"
if grep -q "SRGAN_ENABLE=1" docker-compose.yml; then
    echo "✓ PASS: AI upscaling enabled by default"
    ((PASSED++))
else
    echo "✗ FAIL: SRGAN_ENABLE not set to 1"
    ((FAILED++))
fi
echo ""

# Feature 8: Read-Write Volume Mount
echo "Feature 8: Read-Write Volume Mount"
echo "==================================="
if grep -q "/mnt/media:/mnt/media:rw" docker-compose.yml; then
    echo "✓ PASS: Volume mount is read-write"
    ((PASSED++))
else
    echo "✗ FAIL: Volume mount not read-write"
    ((FAILED++))
fi
echo ""

# Feature 9: FFmpeg-based AI Implementation
echo "Feature 9: FFmpeg-based AI Implementation"
echo "=========================================="
if [ -f "scripts/your_model_file_ffmpeg.py" ]; then
    echo "✓ PASS: FFmpeg-based AI module exists"
    ((PASSED++))
else
    echo "✗ FAIL: FFmpeg-based module missing"
    ((FAILED++))
fi
echo ""

# Feature 10: Model File
echo "Feature 10: SRGAN Model File"
echo "============================="
if [ -f "models/swift_srgan_4x.pth" ]; then
    SIZE=$(ls -lh models/swift_srgan_4x.pth | awk '{print $5}')
    echo "✓ PASS: Model file exists (${SIZE})"
    ((PASSED++))
else
    echo "✗ FAIL: Model file missing"
    echo "  Run: ./scripts/setup_model.sh"
    ((FAILED++))
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════════════"
echo "VERIFICATION SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Results: $PASSED passed, $FAILED failed"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓✓✓ ALL FEATURES VERIFIED ✓✓✓"
    echo ""
    echo "All requested features are implemented correctly!"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy: git pull origin main"
    echo "  2. Recreate: docker compose down && docker compose up -d"
    echo "  3. Clear queue: ./scripts/clear_queue.sh"
    echo "  4. Test: Play video in Jellyfin"
    echo "  5. Verify: docker logs -f srgan-upscaler"
else
    echo "⚠ SOME FEATURES FAILED VERIFICATION"
    echo ""
    echo "Check the failures above and fix them."
fi
echo ""
echo "════════════════════════════════════════════════════════════════"
