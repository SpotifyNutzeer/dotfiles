#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/system.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- _apply_askpass_edit: trägt askpass ein, idempotent, respektiert Bestand ---
printf '# Default sudo.conf\n#Path askpass /usr/X11R6/bin/ssh-askpass\n' > "$tmp/sudo.conf"

_apply_askpass_edit "$tmp/sudo.conf" /usr/bin/ksshaskpass
assert_contains "$(cat "$tmp/sudo.conf")" "Path askpass /usr/bin/ksshaskpass" \
    "_apply_askpass_edit trägt den Helper ein"

_apply_askpass_edit "$tmp/sudo.conf" /usr/bin/ksshaskpass
assert_eq "$(grep -c '^Path askpass ' "$tmp/sudo.conf")" "1" \
    "_apply_askpass_edit ist idempotent"

printf 'Path askpass /usr/bin/anderer-helper\n' > "$tmp/custom.conf"
_apply_askpass_edit "$tmp/custom.conf" /usr/bin/ksshaskpass
assert_eq "$(cat "$tmp/custom.conf")" "Path askpass /usr/bin/anderer-helper" \
    "_apply_askpass_edit überschreibt vorhandene askpass-Konfiguration nicht"

finish
