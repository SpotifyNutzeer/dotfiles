#!/bin/bash
find /usr/share/applications ~/.local/share/applications -maxdepth 2 -name "*.desktop" 2>/dev/null | \
while IFS= read -r f; do
    name=$(grep -m1 '^Name='       "$f" 2>/dev/null | cut -d= -f2-)
    exec=$(grep -m1 '^Exec='       "$f" 2>/dev/null | cut -d= -f2- | sed 's/ *%[a-zA-Z]//g')
    nodisplay=$(grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2-)
    hidden=$(grep -m1    '^Hidden='    "$f" 2>/dev/null | cut -d= -f2-)

    [ "$nodisplay" = "true" ] && continue
    [ "$hidden"    = "true" ] && continue
    [ -z "$name"  ] && continue
    [ -z "$exec"  ] && continue

    printf '%s|%s\n' "$name" "$exec"
done | sort -u -t'|' -k1
