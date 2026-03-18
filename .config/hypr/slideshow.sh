#!/bin/bash
# Wallpaper slideshow for hyprpaper
# Rotates wallpapers from WALLPAPER_DIR across all connected monitors

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
INTERVAL=300  # seconds between wallpaper changes

# Wait for hyprpaper to be ready
sleep 2

declare -A current_wallpapers

while true; do
    # Get all connected monitors dynamically
    mapfile -t MONITORS < <(hyprctl monitors -j | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

    # Collect all wallpaper files
    mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( \
        -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \
        -o -iname "*.webp" -o -iname "*.gif" \
    \) | sort)

    if [ ${#WALLPAPERS[@]} -eq 0 ]; then
        echo "No wallpapers found in $WALLPAPER_DIR" >&2
        sleep "$INTERVAL"
        continue
    fi

    for monitor in "${MONITORS[@]}"; do
        # Pick a random wallpaper (different from the current one)
        while true; do
            new_wp="${WALLPAPERS[RANDOM % ${#WALLPAPERS[@]}]}"
            [ "$new_wp" != "${current_wallpapers[$monitor]}" ] && break
            [ ${#WALLPAPERS[@]} -eq 1 ] && break  # only one wallpaper available
        done

        hyprctl hyprpaper preload "$new_wp" 2>/dev/null
        hyprctl hyprpaper wallpaper "$monitor,$new_wp"

        # Unload previous wallpaper to free memory
        if [ -n "${current_wallpapers[$monitor]}" ]; then
            hyprctl hyprpaper unload "${current_wallpapers[$monitor]}" 2>/dev/null
        fi

        current_wallpapers[$monitor]="$new_wp"
    done

    sleep "$INTERVAL"
done
