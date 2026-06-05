#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Arch
printf 'ID=arch\n' > "$tmp/arch"
OS_RELEASE="$tmp/arch" detect_distro
assert_eq "$DETECTED_DISTRO" "arch" "detect_distro erkennt arch"

# Debian via ID
printf 'ID=debian\n' > "$tmp/debian"
OS_RELEASE="$tmp/debian" detect_distro
assert_eq "$DETECTED_DISTRO" "debian" "detect_distro erkennt debian"

# Ubuntu via ID_LIKE
printf 'ID=ubuntu\nID_LIKE=debian\n' > "$tmp/ubuntu"
OS_RELEASE="$tmp/ubuntu" detect_distro
assert_eq "$DETECTED_DISTRO" "debian" "detect_distro mappt ubuntu auf debian"

# Fedora
printf 'ID=fedora\n' > "$tmp/fedora"
OS_RELEASE="$tmp/fedora" detect_distro
assert_eq "$DETECTED_DISTRO" "fedora" "detect_distro erkennt fedora"

# Unbekannt
printf 'ID=plan9\n' > "$tmp/unknown"
OS_RELEASE="$tmp/unknown" detect_distro
assert_eq "$DETECTED_DISTRO" "unknown" "detect_distro fällt auf unknown zurück"

finish
