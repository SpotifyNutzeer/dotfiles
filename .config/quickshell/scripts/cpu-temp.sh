#!/bin/sh
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = "k10temp" ] || continue
  awk '{print int($1/1000)}' "$h/temp1_input"
  exit 0
done
