#!/usr/bin/env bash
# Paket-Parsing und -Installation. Setzt lib/common.sh als gesourct voraus.

# parse_package_list <file> — gibt eine Paket pro Zeile aus,
# ohne Kommentare (#...), ohne Leerzeilen, getrimmt.
parse_package_list() {
    local file="$1"
    [[ -r "$file" ]] || return 0
    while IFS= read -r line; do
        line="${line%%#*}"                       # Kommentar ab # entfernen
        line="${line#"${line%%[![:space:]]*}"}"  # links trimmen
        line="${line%"${line##*[![:space:]]}"}"  # rechts trimmen
        [[ -n "$line" ]] && printf '%s\n' "$line"
    done < "$file"
}
