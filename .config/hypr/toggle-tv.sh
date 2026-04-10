#!/usr/bin/env bash
CONF="$HOME/.config/hypr/hyprland.conf"
TV_SINK="alsa_output.pci-0000_01_00.1.hdmi-stereo"
DEFAULT_SINK="sink_rode_game"

if hyprctl monitors | grep -q "^Monitor HDMI-A-1"; then
    # TV ausschalten: DP-1 zurück auf 240Hz, HDMI-A-1 deaktivieren, Audio zurückschalten
    sed -i 's/mode = 3840x2160@119\.88/mode = 3840x2160@239.99/' "$CONF"
    sed -i 's/^monitor = HDMI-A-1.*/monitor = HDMI-A-1, disable/' "$CONF"
    pactl set-default-sink "$DEFAULT_SINK"
    hyprctl reload
else
    # TV einschalten: DP-1 auf 120Hz, HDMI-A-1 aktivieren, Audio auf TV
    sed -i 's/mode = 3840x2160@239\.99/mode = 3840x2160@119.88/' "$CONF"
    sed -i 's|^monitor = HDMI-A-1.*|monitor = HDMI-A-1, 3840x2160@120, 3840x1440, 1, bitdepth, 10, cm, hdredid|' "$CONF"
    pactl set-default-sink "$TV_SINK"
    hyprctl reload
fi
