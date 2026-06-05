#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/packages.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

conf="$tmp/pacman.conf"
# Auszug einer frischen Arch-pacman.conf (relevante Defaults, alle kommentiert)
cat > "$conf" <<'EOF'
[options]
#Color
#ParallelDownloads = 5

#[multilib-testing]
#Include = /etc/pacman.d/mirrorlist

#[multilib]
#Include = /etc/pacman.d/mirrorlist
EOF

_apply_pacman_edits "$conf"

assert_eq "$(grep -c '^Color$' "$conf")" "1" "Color aktiviert"
assert_eq "$(grep -c '^ParallelDownloads = 5$' "$conf")" "1" "ParallelDownloads aktiviert"
assert_eq "$(grep -c '^\[multilib\]$' "$conf")" "1" "[multilib] aktiviert"
assert_eq "$(sed -n '/^\[multilib\]$/{n;p}' "$conf")" "Include = /etc/pacman.d/mirrorlist" "multilib Include aktiviert"
assert_eq "$(grep -c '^#\[multilib-testing\]$' "$conf")" "1" "multilib-testing bleibt deaktiviert"

# Idempotenz: zweiter Lauf ändert nichts mehr
before="$(cat "$conf")"
_apply_pacman_edits "$conf"
assert_eq "$(cat "$conf")" "$before" "_apply_pacman_edits ist idempotent"

finish
