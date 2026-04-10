#!/bin/bash
# Average clock across all cores in MHz
freq=$(awk '{sum+=$1; n++} END {printf "%.0f", sum/n/1000}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)
echo "${freq}MHz"
