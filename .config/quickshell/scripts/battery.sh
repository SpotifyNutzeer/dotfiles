#!/bin/sh
# Akkustand, Ladezustand und geschaetzte Restlaufzeit in Minuten.
# Nur Laptops haben BAT0; auf Geraeten ohne Akku gibt es keine Ausgabe.
# Ausgabe: "<capacity> <status> <minutes>"  (minutes = -1 wenn unbekannt)
bat=/sys/class/power_supply/BAT0
[ -r "$bat/capacity" ] || exit 0
cap=$(cat "$bat/capacity" 2>/dev/null)
stat=$(cat "$bat/status" 2>/dev/null)

# Restlaufzeit aus energy_now/power_now (beide in µWh bzw. µW):
#   Entladen:  verbleibende Energie / aktuelle Leistung
#   Laden:     (Voll - aktuell) / aktuelle Leistung  -> Zeit bis voll
mins=-1
pw=$(cat "$bat/power_now"   2>/dev/null)
en=$(cat "$bat/energy_now"  2>/dev/null)
ef=$(cat "$bat/energy_full" 2>/dev/null)
if [ -n "$pw" ] && [ "$pw" -gt 0 ] 2>/dev/null; then
  case "$stat" in
    Discharging) [ -n "$en" ] &&                 mins=$(( en * 60 / pw )) ;;
    Charging)    [ -n "$ef" ] && [ -n "$en" ] && mins=$(( (ef - en) * 60 / pw )) ;;
  esac
fi
echo "$cap $stat $mins"
