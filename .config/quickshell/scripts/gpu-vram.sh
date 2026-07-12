#!/bin/sh
# NVIDIA falls vorhanden, sonst AMD (amdgpu) via sysfs
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | awk '{printf "%dM", $1}'
else
    used=$(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -1)
    [ -n "$used" ] && echo "$((used / 1024 / 1024))M"
fi
