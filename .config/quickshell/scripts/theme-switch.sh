#!/bin/sh
# Schaltet das Quickshell-Theme um.
#   theme-switch.sh toggle   -> rotiert Mocha -> Liquidglass -> Zen
#   theme-switch.sh menu     -> Rofi-Auswahl
# Persistenz + Hyprland-/Rofi-Kopplung erledigt die Shell selbst.

ROFI_THEME="$HOME/.local/state/quickshell/rofi-theme.rasi"
[ -e "$ROFI_THEME" ] || ROFI_THEME="$HOME/.config/rofi/catppuccin-mocha.rasi"

case "$1" in
    toggle)
        qs ipc call theme toggle
        ;;
    menu)
        MOCHA="󰧉 Mocha"
        GLASS="󰂭 Liquidglass"
        ZEN="󱅻 Zen"
        CHOICE=$(printf "%s\n%s\n%s" "$MOCHA" "$GLASS" "$ZEN" \
            | rofi -dmenu \
                -p "󰸉" \
                -theme "$ROFI_THEME" \
                -theme-str 'window { width: 220px; } listview { lines: 3; }')
        case "$CHOICE" in
            "$MOCHA") qs ipc call theme setVariant mocha ;;
            "$GLASS") qs ipc call theme setVariant liquidglass ;;
            "$ZEN")   qs ipc call theme setVariant zen ;;
        esac
        ;;
    *)
        echo "usage: $0 {toggle|menu}" >&2
        exit 1
        ;;
esac
