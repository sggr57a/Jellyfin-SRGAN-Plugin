#!/bin/bash
#
# GPU Detection Script for RealTimeHDRSRGAN Plugin
#

if command -v nvidia-smi &>/dev/null; then
    echo "SUCCESS: NVIDIA GPU detected"
    echo ""
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | while IFS=',' read -r name memory; do
        echo "GPU: $name"
        echo "Memory: $memory"
    done
    exit 0
else
    echo "ERROR: No NVIDIA GPU detected"
    echo "nvidia-smi command not found"
    exit 1
fi
