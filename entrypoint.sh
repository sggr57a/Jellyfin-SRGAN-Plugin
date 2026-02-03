#!/bin/bash
set -e

# Apply NVIDIA patch if GPU is available and not already patched
if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi >/dev/null 2>&1; then
        echo "GPU detected, checking NVIDIA driver patch status..."
        if [ -d /opt/nvidia-patch ]; then
            cd /opt/nvidia-patch
            # Try to apply patch, ignore errors if already patched
            if bash ./patch.sh 2>&1 | tee /tmp/patch.log | grep -q "Already patched\|Patched\|Success"; then
                echo "✓ NVIDIA driver patch applied/verified"
            else
                # Check if it's just already patched
                if grep -q "already" /tmp/patch.log 2>/dev/null; then
                    echo "✓ NVIDIA driver already patched"
                else
                    echo "⚠ NVIDIA patch skipped (may not be needed for this driver)"
                fi
            fi
        else
            echo "⚠ nvidia-patch directory not found, skipping"
        fi
    else
        echo "GPU not accessible in container, skipping NVIDIA patch"
    fi
else
    echo "nvidia-smi not found, skipping NVIDIA patch"
fi

echo ""
echo "Starting SRGAN pipeline..."

# Run the main application with all arguments
exec python /app/scripts/srgan_pipeline.py "$@"
