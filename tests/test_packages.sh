#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/packages.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/list.txt" <<'EOF'
# ein Kommentar
fish

kitty
  vim
EOF

result="$(parse_package_list "$tmp/list.txt" | tr '\n' ' ')"
assert_eq "$result" "fish kitty vim " "parse_package_list ignoriert Kommentare/Leerzeilen, trimmt"

empty="$(parse_package_list "$tmp/does-not-exist.txt"; echo done)"
assert_eq "$empty" "done" "parse_package_list verträgt fehlende Datei"

finish
