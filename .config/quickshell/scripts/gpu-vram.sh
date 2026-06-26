#!/bin/sh
nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | awk '{printf "%dM", $1}'
