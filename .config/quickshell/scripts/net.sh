#!/bin/sh
# Interface der Default-Route automatisch waehlen (Desktop-Ethernet wie Laptop-WLAN).
iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
# Fallback: erstes hochgefahrenes, nicht-virtuelles Interface
[ -z "$iface" ] && iface=$(ls /sys/class/net | grep -vE '^(lo|docker|veth|virbr|br-|tun|tap)' | head -1)
[ -z "$iface" ] && { echo "0K 0K"; exit; }
r1=$(cat /sys/class/net/$iface/statistics/rx_bytes)
t1=$(cat /sys/class/net/$iface/statistics/tx_bytes)
sleep 1
r2=$(cat /sys/class/net/$iface/statistics/rx_bytes)
t2=$(cat /sys/class/net/$iface/statistics/tx_bytes)
rd=$((r2-r1)); td=$((t2-t1))
fmt() { [[ $1 -lt 1048576 ]] && echo "$((($1+512)/1024))K" || awk "BEGIN{printf \"%.1fM\",$1/1048576}"; }
echo "$(fmt $rd) $(fmt $td)"
