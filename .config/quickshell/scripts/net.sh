#!/bin/sh
iface=enp14s0
r1=$(cat /sys/class/net/$iface/statistics/rx_bytes)
t1=$(cat /sys/class/net/$iface/statistics/tx_bytes)
sleep 1
r2=$(cat /sys/class/net/$iface/statistics/rx_bytes)
t2=$(cat /sys/class/net/$iface/statistics/tx_bytes)
rd=$((r2-r1)); td=$((t2-t1))
fmt() { [[ $1 -lt 1048576 ]] && echo "$((($1+512)/1024))K" || awk "BEGIN{printf \"%.1fM\",$1/1048576}"; }
echo "$(fmt $rd) $(fmt $td)"
