#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/symlinks.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

src="$tmp/repo/foo"
mkdir -p "$src"
printf 'hi\n' > "$src/file"

# Fall 1: Ziel existiert nicht -> Symlink wird angelegt
dst="$tmp/home/foo"
mkdir -p "$tmp/home"
CONFLICT_ALL="" link_item "$src" "$dst"
assert_symlink_to "$dst" "$src" "link_item legt fehlenden Symlink an"

# Fall 2: Ziel ist bereits korrekter Symlink -> idempotent, kein Fehler
CONFLICT_ALL="" link_item "$src" "$dst"
assert_symlink_to "$dst" "$src" "link_item ist idempotent bei korrektem Symlink"

# Fall 3: Konflikt, CONFLICT_ALL=backup -> altes Ziel wird gesichert, Symlink gesetzt
dst2="$tmp/home/bar"
mkdir -p "$tmp/repo/bar"
printf 'realdata\n' > "$dst2"   # echte Datei im Weg
BACKUP_DIR="$tmp/backup" CONFLICT_ALL="backup" link_item "$tmp/repo/bar" "$dst2"
assert_symlink_to "$dst2" "$tmp/repo/bar" "link_item setzt Symlink nach Backup"
assert_eq "$(cat "$tmp/backup/bar")" "realdata" "link_item sichert Konflikt-Datei ins Backup"

finish
