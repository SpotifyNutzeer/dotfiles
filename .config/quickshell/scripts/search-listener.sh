#!/bin/bash
FIFO="/tmp/qs-search-toggle"
rm -f "$FIFO"
mkfifo "$FIFO"
while true; do
    read -r _ < "$FIFO"
    echo "toggle"
done
