#!/bin/sh

LOCK="󰌾 Sperren"
SUSPEND="󰤄 Ruhezustand"
LOGOUT="󰍃 Abmelden"
REBOOT="󰑓 Neustart"
WINDOWS="󰖳 Windows"
SHUTDOWN="󰐥 Ausschalten"

CHOICE=$(printf "%s\n%s\n%s\n%s\n%s\n%s" "$LOCK" "$SUSPEND" "$LOGOUT" "$REBOOT" "$WINDOWS" "$SHUTDOWN" \
    | rofi -dmenu \
        -p "󰐥" \
        -theme ~/.config/rofi/catppuccin-mocha.rasi \
        -theme-str 'window { width: 220px; } listview { lines: 6; }')

case "$CHOICE" in
    "$LOCK")     loginctl lock-session ;;
    "$SUSPEND")  systemctl suspend ;;
    "$LOGOUT")   hyprctl dispatch exit ;;
    "$REBOOT")   systemctl reboot ;;
    "$WINDOWS")  systemctl reboot --boot-loader-entry=auto-windows ;;
    "$SHUTDOWN") systemctl poweroff ;;
esac
