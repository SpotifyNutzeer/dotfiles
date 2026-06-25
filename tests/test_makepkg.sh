#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/packages.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

conf="$tmp/makepkg.conf"

# Fall 1: Arch-Default (enthält 'debug', kein '!debug') -> wird auf !debug umgestellt.
printf 'OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug lto)\n' > "$conf"
_apply_makepkg_nodebug "$conf"
assert_eq "$(cat "$conf")" \
    'OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge lto !debug)' \
    "Arch-Default: debug -> !debug"

# Fall 2: unsaubere Zeile (debug UND !debug) -> dedupliziert zu genau einem !debug.
printf 'OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug lto !debug)\n' > "$conf"
_apply_makepkg_nodebug "$conf"
assert_eq "$(grep -c -- '!debug' "$conf")" "1" "genau ein !debug nach Bereinigung"
assert_eq "$(grep -cE '[[:space:](]debug[[:space:])]' "$conf")" "0" "kein eigenständiges debug mehr"

# Idempotenz: zweiter Lauf ändert nichts.
before="$(cat "$conf")"
_apply_makepkg_nodebug "$conf"
assert_eq "$(cat "$conf")" "$before" "_apply_makepkg_nodebug ist idempotent"

# Fall 3: auskommentierte OPTIONS-Zeile bleibt unangetastet.
printf '#OPTIONS=(strip debug)\nOPTIONS=(strip !debug lto)\n' > "$conf"
before="$(cat "$conf")"
_apply_makepkg_nodebug "$conf"
assert_eq "$(cat "$conf")" "$before" "Kommentarzeile + bereits korrekte Zeile unverändert"

# _makepkg_debug_disabled: Prädikat erkennt beide Zustände korrekt.
printf 'OPTIONS=(strip lto !debug)\n' > "$conf"
_makepkg_debug_disabled "$conf"; assert_eq "$?" "0" "Prädikat: !debug erkannt"
printf 'OPTIONS=(strip lto debug)\n' > "$conf"
_makepkg_debug_disabled "$conf"; assert_eq "$?" "1" "Prädikat: eigenständiges debug erkannt"

finish
