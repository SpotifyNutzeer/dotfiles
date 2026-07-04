#!/bin/sh
# NVIDIA falls vorhanden, sonst AMD (amdgpu) via sysfs
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits
else
    cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1
fi
