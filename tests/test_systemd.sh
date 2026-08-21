#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/symlinks.sh
source ../lib/systemd.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

user="$tmp/user"
mkdir -p "$user/default.target.wants" "$user/graphical-session.target.wants" \
         "$user/xdg-desktop-autostart.target.wants"

# Eigene Unit + wants-Symlink auf die Home-Kopie
printf '[Unit]\n' > "$user/dac-keepalive.service"
ln -s ../dac-keepalive.service "$user/default.target.wants/dac-keepalive.service"
# wants-Symlinks auf paket-Units (Ziel muss nicht existieren -> dangling, -L greift)
ln -s /usr/lib/systemd/user/hyprpolkitagent.service \
    "$user/graphical-session.target.wants/hyprpolkitagent.service"
ln -s /usr/lib/systemd/user/sunshine.service \
    "$user/xdg-desktop-autostart.target.wants/sunshine.service"

result="$(_systemd_wanted_services "$user" | tr '\n' ' ')"
assert_eq "$result" "dac-keepalive.service hyprpolkitagent.service sunshine.service " \
    "_systemd_wanted_services sammelt alle wants dedupliziert"

assert_eq "$(_systemd_is_skipped sunshine.service && echo yes || echo no)" "yes" \
    "_systemd_is_skipped erkennt sunshine"
assert_eq "$(_systemd_is_skipped dac-keepalive.service && echo yes || echo no)" "no" \
    "_systemd_is_skipped lässt dac-keepalive durch"

finish
