#!/bin/sh
# NVIDIA falls vorhanden, sonst AMD (amdgpu) via hwmon
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo "0"
else
    for h in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$h/name" 2>/dev/null)" = "amdgpu" ] || continue
        awk '{print int($1/1000)}' "$h/temp1_input" 2>/dev/null && exit 0
    done
    echo "0"
fi
