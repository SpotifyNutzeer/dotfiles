#!/bin/sh
# Try nvidia-smi first, fall back to AMD sysfs
if command -v nvidia-smi &>/dev/null; then
    freq=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits 2>/dev/null)
    echo "${freq}MHz"
else
    freq=$(cat /sys/class/drm/card*/device/pp_dpm_sclk 2>/dev/null | grep '\*' | awk '{print $2}')
    echo "${freq}MHz"
fi
