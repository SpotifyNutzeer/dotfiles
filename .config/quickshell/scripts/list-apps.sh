#!/bin/bash
find /usr/share/applications ~/.local/share/applications -maxdepth 2 -name "*.desktop" 2>/dev/null | \
while IFS= read -r f; do
    name=$(grep -m1 '^Name='       "$f" 2>/dev/null | cut -d= -f2-)
    exec=$(grep -m1 '^Exec='       "$f" 2>/dev/null | cut -d= -f2- | sed 's/ *%[a-zA-Z]//g')
    icon=$(grep -m1 '^Icon='       "$f" 2>/dev/null | cut -d= -f2-)
    nodisplay=$(grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2-)
    hidden=$(grep -m1    '^Hidden='    "$f" 2>/dev/null | cut -d= -f2-)

    [ "$nodisplay" = "true" ] && continue
    [ "$hidden"    = "true" ] && continue
    [ -z "$name"  ] && continue
    [ -z "$exec"  ] && continue

    # Resolve icon name to a file path
    icon_path=""
    if [ -n "$icon" ]; then
        # Already an absolute path
        if [ -f "$icon" ]; then
            icon_path="$icon"
        else
            # Search common icon locations (prefer png, then svg)
            for size in 48x48 32x32 64x64 256x256 scalable; do
                for dir in \
                    /usr/share/icons/hicolor/$size/apps \
                    /usr/share/icons/Papirus/$size/apps \
                    /usr/share/icons/breeze/$size/apps \
                    /usr/share/icons/Adwaita/$size/apps \
                    ~/.local/share/icons/hicolor/$size/apps; do
                    for ext in png svg xpm; do
                        candidate="$dir/$icon.$ext"
                        if [ -f "$candidate" ]; then
                            icon_path="$candidate"
                            break 3
                        fi
                    done
                done
            done
            # Fallback: pixmaps
            if [ -z "$icon_path" ]; then
                for ext in png svg xpm; do
                    candidate="/usr/share/pixmaps/$icon.$ext"
                    [ -f "$candidate" ] && icon_path="$candidate" && break
                done
            fi
        fi
    fi

    printf '%s|%s|%s\n' "$name" "$exec" "$icon_path"
done | sort -u -t'|' -k1
