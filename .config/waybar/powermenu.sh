#!/bin/bash

LOCK="󰌾 Sperren"
SUSPEND="󰤄 Ruhezustand"
LOGOUT="󰍃 Abmelden"
REBOOT="󰑓 Neustart"
SHUTDOWN="󰐥 Ausschalten"

CHOICE=$(printf "%s\n%s\n%s\n%s\n%s" "$LOCK" "$SUSPEND" "$LOGOUT" "$REBOOT" "$SHUTDOWN" \
    | rofi -dmenu \
        -p "󰐥" \
        -theme ~/.config/rofi/catppuccin-mocha.rasi \
        -theme-str 'window { width: 220px; } listview { lines: 5; }')

case "$CHOICE" in
    "$LOCK")     loginctl lock-session ;;
    "$SUSPEND")  systemctl suspend ;;
    "$LOGOUT")   hyprctl dispatch exit ;;
    "$REBOOT")   systemctl reboot ;;
    "$SHUTDOWN") systemctl poweroff ;;
esac
