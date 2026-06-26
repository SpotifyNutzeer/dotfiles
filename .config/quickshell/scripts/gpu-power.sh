#!/bin/sh
nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | awk '{printf "%d", $1}'
