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

# _apply_pacman_edits <conf> — aktiviert Color, ParallelDownloads und [multilib]
# in der gegebenen pacman.conf. Idempotent, editiert die Datei direkt (der
# Aufrufer sorgt für Schreibrechte). Reine Funktion -> testbar ohne sudo.
_apply_pacman_edits() {
    local conf="$1"
    grep -q '^#Color' "$conf" && sed -i 's/^#Color/Color/' "$conf"
    grep -q '^#ParallelDownloads' "$conf" && sed -i 's/^#ParallelDownloads/ParallelDownloads/' "$conf"
    # multilib nur aktivieren, wenn nicht bereits aktiv. Der Range entfernt das
    # führende # von der [multilib]-Zeile bis zur zugehörigen Include-Zeile.
    grep -q '^\[multilib\]' "$conf" || sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "$conf"
    return 0
}

# configure_pacman — wendet _apply_pacman_edits auf /etc/pacman.conf an
# (mit einmaligem Backup, via sudo). Nur Arch.
configure_pacman() {
    local conf="/etc/pacman.conf"
    [[ -f "$conf" ]] || { log_warn "$conf nicht gefunden — übersprungen"; return 0; }

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] $conf anpassen: Color, ParallelDownloads, [multilib] (mit Backup)"
        return 0
    fi

    [[ -f "$conf.dotfiles-bak" ]] || sudo cp "$conf" "$conf.dotfiles-bak"
    # Funktion in eine root-Shell exportieren, damit die Edits Schreibrechte haben.
    sudo bash -c "$(declare -f _apply_pacman_edits); _apply_pacman_edits '$conf'"
    log_ok "pacman.conf angepasst (Color, ParallelDownloads, multilib)"
}

# Bekannte Display-Manager außer sddm.
_OTHER_DISPLAY_MANAGERS=(gdm lightdm lxdm ly greetd entrance slim xdm)

# _other_dm_present — 0 (true), wenn ein ANDERER Display-Manager als sddm aktiv
# oder installiert ist. Dann fassen wir den DM nicht an.
_other_dm_present() {
    local link dm
    if link="$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)"; then
        [[ "$link" == *sddm* ]] || return 0   # ein anderer DM ist aktiv
    fi
    for dm in "${_OTHER_DISPLAY_MANAGERS[@]}"; do
        pacman -Q "$dm" >/dev/null 2>&1 && return 0
    done
    return 1
}

# setup_sddm — installiert + konfiguriert SDDM, sofern kein anderer DM vorhanden
# ist. Idempotent. Setzt voraus, dass _ensure_yay nutzbar ist.
setup_sddm() {
    if _other_dm_present; then
        log_info "anderer Display-Manager vorhanden — SDDM übersprungen"
        return 0
    fi

    log_info "richte SDDM ein"
    run sudo pacman -S --needed --noconfirm sddm
    if _ensure_yay; then
        run yay -S --needed --noconfirm catppuccin-sddm-theme-mocha
    fi

    # Theme-Konfiguration nach /etc/sddm.conf.d/ (legt das Verzeichnis bei Bedarf an).
    local src="$DOTFILES_DIR/system/sddm.conf.d/theme.conf"
    [[ -f "$src" ]] && run sudo install -Dm 644 "$src" /etc/sddm.conf.d/theme.conf

    run sudo systemctl enable sddm.service
    log_ok "SDDM aktiviert"
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
    # pacman.conf zuerst anpassen (u.a. multilib), dann DBs syncen + upgraden,
    # damit die multilib-Datenbank verfügbar ist und kein Partial-Upgrade passiert.
    configure_pacman
    log_info "synchronisiere Paketdatenbanken + System (pacman -Syu)"
    run sudo pacman -Syu --noconfirm

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

    # Display-Manager (SDDM), sofern kein anderer vorhanden.
    setup_sddm
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
    run sudo apt-get update || log_warn "apt-get update fehlgeschlagen — fahre fort"
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
