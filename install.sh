#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

DRY_RUN=0
NO_PACKAGES=0
DISTRO_OVERRIDE=""

usage() {
    cat <<EOF
Usage: ./install.sh [Optionen]

  --no-packages        Nur Symlinks/systemd/fisher, keine Paketinstallation
  --dry-run            Aktionen nur anzeigen, nichts ausführen
  --distro <name>      Distro-Erkennung übersteuern (arch|debian|fedora)
  -h, --help           Diese Hilfe
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-packages) NO_PACKAGES=1; shift ;;
        --dry-run)     DRY_RUN=1; shift ;;
        --distro)
            DISTRO_OVERRIDE="${2:-}"
            case "$DISTRO_OVERRIDE" in
                arch|debian|fedora) ;;
                *) echo "Fehler: --distro braucht ein Argument (arch|debian|fedora)" >&2; usage; exit 1 ;;
            esac
            shift 2
            ;;
        -h|--help)     usage; exit 0 ;;
        *)             echo "Unbekannte Option: $1" >&2; usage; exit 1 ;;
    esac
done
export DRY_RUN

# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/packages.sh"
source "$DOTFILES_DIR/lib/symlinks.sh"
source "$DOTFILES_DIR/lib/systemd.sh"
source "$DOTFILES_DIR/lib/fisher.sh"

# Distro bestimmen
if [[ -n "$DISTRO_OVERRIDE" ]]; then
    DETECTED_DISTRO="$DISTRO_OVERRIDE"
else
    detect_distro
fi
log_info "Distro: $DETECTED_DISTRO"
[[ "$DRY_RUN" -eq 1 ]] && log_info "DRY-RUN aktiv — es wird nichts verändert"

if [[ "$DETECTED_DISTRO" == "unknown" ]]; then
    log_error "Distro nicht erkannt. Nutze --distro <arch|debian|fedora>."
    exit 1
fi

# 1. Pakete
if [[ "$NO_PACKAGES" -eq 1 ]]; then
    log_info "Paketinstallation übersprungen (--no-packages)"
else
    install_packages "$DETECTED_DISTRO"
fi

# 2. Symlinks
log_info "verlinke Dotfiles"
link_dotfiles

# 3. systemd
log_info "richte systemd-User-Services ein"
setup_systemd_services

# 4. fisher
log_info "richte fish-Plugins ein"
setup_fisher

# 5. Abschluss-Hinweise
cat >&2 <<'EOF'

────────────────────────────────────────────────────────
Fertig. Hinweise:

• Papirus-Ordnerfarbe (optional):
    papirus-folders -C cat-mocha-teal --theme Papirus-Dark

• rodecaster-tidal-bridge ist NICHT Teil dieses Installers.
  Eigenes Projekt: https://github.com/SpotifyNutzeer/rodecaster-tidal-bridge
  Manuell klonen/einrichten (config.toml wurde mitverlinkt).
────────────────────────────────────────────────────────
EOF
