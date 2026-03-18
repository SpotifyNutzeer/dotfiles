#!/bin/bash
prev=($(awk 'NR==1{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat))
sleep 1
curr=($(awk 'NR==1{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat))
total_prev=0; for v in "${prev[@]}"; do ((total_prev+=v)); done
total_curr=0; for v in "${curr[@]}"; do ((total_curr+=v)); done
echo "$(( (total_curr-total_prev-curr[3]+prev[3]) * 100 / (total_curr-total_prev) ))"
