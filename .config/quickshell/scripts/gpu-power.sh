#!/bin/sh
# NVIDIA falls vorhanden, sonst AMD (amdgpu) via hwmon. Ausgabe: nackte Zahl (W),
# das "W" haengt Bar.qml selbst an.
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | awk '{printf "%d", $1}'
else
    for h in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$h/name" 2>/dev/null)" = "amdgpu" ] || continue
        # power1_average in Mikrowatt
        awk '{printf "%d", $1/1000000}' "$h/power1_average" 2>/dev/null && exit 0
    done
fi
