#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/apps.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- tidal-hifi.desktop-Override: Exec zeigt auf den Wrapper, Flags bleiben erhalten ---
cat > "$tmp/tidal-hifi.desktop" <<'EOF'
[Desktop Entry]
Name=TIDAL Hi-Fi
Exec=tidal-hifi --enable-features=UseOzonePlatform --ozone-platform-hint=auto %U
MimeType=x-scheme-handler/tidal;
EOF
_apply_tidaluna_desktop_edit "$tmp/tidal-hifi.desktop" "$tmp/override.desktop" /home/x/.local/bin/tidal-hifi

assert_eq "$(grep -c '^Exec=/home/x/.local/bin/tidal-hifi ' "$tmp/override.desktop")" "1" \
    "_apply_tidaluna_desktop_edit biegt Exec auf den Wrapper um"
assert_eq "$(grep -c '^Exec=tidal-hifi' "$tmp/override.desktop")" "0" \
    "_apply_tidaluna_desktop_edit lässt kein nacktes tidal-hifi-Exec übrig"
assert_contains "$(cat "$tmp/override.desktop")" \
    "--enable-features=UseOzonePlatform --ozone-platform-hint=auto %U" \
    "_apply_tidaluna_desktop_edit erbt die Upstream-Flags (Wayland, %U)"
assert_contains "$(cat "$tmp/override.desktop")" "MimeType=x-scheme-handler/tidal;" \
    "_apply_tidaluna_desktop_edit lässt restliche Zeilen unverändert"

# --- der Wrapper selbst nagelt Electron auf gnome-libsecret fest ---
assert_contains "$(cat ../bin/tidal-hifi)" "--password-store=gnome-libsecret" \
    "bin/tidal-hifi setzt --password-store=gnome-libsecret"

finish
