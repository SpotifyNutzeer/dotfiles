#!/bin/sh
# Akku-Rohwerte fuer die Bar. Nur Laptops haben BAT0; auf Geraeten ohne Akku
# gibt es keine Ausgabe (die Anzeige bleibt dann ausgeblendet).
# Ausgabe: "<capacity> <status> <power_uW> <energy_now_uWh> <energy_full_uWh>"
# Glaettung (gleitender Mittel der Leistung) und Restlaufzeit rechnet die QML,
# damit Watt-Anzeige und Schaetzung dieselbe beruhigte Leistung nutzen.
bat=/sys/class/power_supply/BAT0
[ -r "$bat/capacity" ] || exit 0
cap=$(cat "$bat/capacity"    2>/dev/null)
stat=$(cat "$bat/status"     2>/dev/null)
pw=$(cat "$bat/power_now"    2>/dev/null); [ -n "$pw" ] || pw=0
en=$(cat "$bat/energy_now"   2>/dev/null); [ -n "$en" ] || en=0
ef=$(cat "$bat/energy_full"  2>/dev/null); [ -n "$ef" ] || ef=0
echo "$cap $stat $pw $en $ef"
