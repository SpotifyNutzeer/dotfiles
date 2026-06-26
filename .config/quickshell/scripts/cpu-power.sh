#!/bin/sh
ENERGY_FILE="/sys/class/powercap/intel-rapl:0/energy_uj"
e1=$(cat "$ENERGY_FILE" 2>/dev/null) || { echo "N/A"; exit; }
sleep 1
e2=$(cat "$ENERGY_FILE" 2>/dev/null)
echo "$(( (e2 - e1) / 1000000 ))W"
