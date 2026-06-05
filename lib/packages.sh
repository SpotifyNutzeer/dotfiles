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

# _ensure_yay — stellt sicher, dass yay verfügbar ist (sonst Bootstrap aus AUR).
_ensure_yay() {
    command -v yay >/dev/null 2>&1 && return 0
    log_info "yay nicht gefunden — bootstrappe aus AUR"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] git clone yay + makepkg -si"
        return 0
    fi
    local tmp; tmp="$(mktemp -d)"
    if git clone https://aur.archlinux.org/yay.git "$tmp/yay" \
        && ( cd "$tmp/yay" && makepkg -si --noconfirm ); then
        rm -rf "$tmp"
        return 0
    fi
    rm -rf "$tmp"
    log_warn "yay-Bootstrap fehlgeschlagen — AUR-Pakete werden übersprungen"
    return 1
}

# install_packages_arch
install_packages_arch() {
    local pacman_list aur_list
    mapfile -t pacman_list < <(parse_package_list "$DOTFILES_DIR/packages/arch-pacman.txt")
    mapfile -t aur_list < <(parse_package_list "$DOTFILES_DIR/packages/arch-aur.txt")

    if [[ "${#pacman_list[@]}" -gt 0 ]]; then
        log_info "installiere pacman-Pakete (${#pacman_list[@]})"
        run sudo pacman -S --needed --noconfirm "${pacman_list[@]}"
    fi

    if [[ "${#aur_list[@]}" -gt 0 ]]; then
        if _ensure_yay; then
            log_info "installiere AUR-Pakete (${#aur_list[@]})"
            run yay -S --needed --noconfirm "${aur_list[@]}"
        fi
    fi
}

# _install_best_effort <installer-cmd...> < liste : versucht jedes Paket einzeln,
# warnt bei Fehlern statt abzubrechen. Pakete kommen über stdin (eine pro Zeile).
_install_best_effort() {
    local pkg
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        if run "$@" "$pkg"; then
            :
        else
            log_warn "Paket nicht installierbar (übersprungen): $pkg"
        fi
    done
}

# install_packages_debian
install_packages_debian() {
    run sudo apt-get update
    parse_package_list "$DOTFILES_DIR/packages/debian.txt" \
        | _install_best_effort sudo apt-get install -y
}

# install_packages_fedora
install_packages_fedora() {
    parse_package_list "$DOTFILES_DIR/packages/fedora.txt" \
        | _install_best_effort sudo dnf install -y
}

# install_packages <distro> — Dispatcher.
install_packages() {
    case "$1" in
        arch)   install_packages_arch ;;
        debian) install_packages_debian ;;
        fedora) install_packages_fedora ;;
        *)      log_warn "unbekannte Distro '$1' — Paketinstallation übersprungen" ;;
    esac
}
