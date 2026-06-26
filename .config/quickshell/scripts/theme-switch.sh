#!/bin/sh
# Schaltet das Quickshell-Theme um.
#   theme-switch.sh toggle   -> wechselt zwischen Mocha und Liquidglass
#   theme-switch.sh menu     -> Rofi-Auswahl
# Persistenz erledigt die Shell selbst (State-Datei).

case "$1" in
    toggle)
        qs ipc call theme toggle
        ;;
    menu)
        MOCHA="󰧉 Mocha"
        GLASS="󰂭 Liquidglass"
        CHOICE=$(printf "%s\n%s" "$MOCHA" "$GLASS" \
            | rofi -dmenu \
                -p "󰸉" \
                -theme "$HOME/.config/rofi/catppuccin-mocha.rasi" \
                -theme-str 'window { width: 220px; } listview { lines: 2; }')
        case "$CHOICE" in
            "$MOCHA") qs ipc call theme setVariant mocha ;;
            "$GLASS") qs ipc call theme setVariant liquidglass ;;
        esac
        ;;
    *)
        echo "usage: $0 {toggle|menu}" >&2
        exit 1
        ;;
esac
