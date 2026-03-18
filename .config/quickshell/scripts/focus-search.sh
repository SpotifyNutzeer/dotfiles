#!/bin/bash
# Open search
echo 1 > /tmp/qs-search-toggle
sleep 0.2

# Current cursor position in logical coords
POS=$(hyprctl cursorpos)
CUR_X=$(echo "$POS" | cut -d',' -f1 | tr -d ' ')
CUR_Y=$(echo "$POS" | cut -d',' -f2 | tr -d ' ')

# Target: centre of search bar on HDMI-A-1 (from hyprctl cursorpos while hovering)
TARGET_X=62
TARGET_Y=1467

# Get scale of the monitor the cursor is currently on
SCALE=$(hyprctl monitors -j | jq --argjson cx "$CUR_X" --argjson cy "$CUR_Y" '
  [.[] | select(
    .x <= ($cx|tonumber) and ($cx|tonumber) < (.x + (.width  / .scale | round)) and
    .y <= ($cy|tonumber) and ($cy|tonumber) < (.y + (.height / .scale | round))
  )] | first | .scale // 1.0
')
SCALE=${SCALE:-1.0}

# Multiply logical delta by scale to get physical pixels for ydotool
DELTA_X=$(awk "BEGIN { printf \"%d\", ($TARGET_X - $CUR_X) * $SCALE }")
DELTA_Y=$(awk "BEGIN { printf \"%d\", ($TARGET_Y - $CUR_Y) * $SCALE }")

ydotool mousemove -- "$DELTA_X" "$DELTA_Y"
ydotool click 0xC0
ydotool mousemove -- $((-DELTA_X)) $((-DELTA_Y))
