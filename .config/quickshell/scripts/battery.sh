#!/bin/sh
# Akkustand + Ladezustand. Nur Laptops haben BAT0; auf Geraeten ohne Akku
# gibt es keine Ausgabe (die Anzeige bleibt dann in der Bar ausgeblendet).
bat=/sys/class/power_supply/BAT0
[ -r "$bat/capacity" ] || exit 0
cap=$(cat "$bat/capacity" 2>/dev/null)
stat=$(cat "$bat/status" 2>/dev/null)
echo "$cap $stat"
