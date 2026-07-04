#!/bin/sh
# NVIDIA falls vorhanden, sonst AMD (amdgpu) via sysfs
if command -v nvidia-smi >/dev/null 2>&1; then
    freq=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits 2>/dev/null)
    echo "${freq}MHz"
else
    # aktive DPM-Stufe (mit '*') aus pp_dpm_sclk, nur die Zahl
    freq=$(awk '/\*/{gsub(/[^0-9]/,"",$2); print $2; exit}' /sys/class/drm/card*/device/pp_dpm_sclk 2>/dev/null)
    echo "${freq}MHz"
fi
