#!/usr/bin/env bash
# Gaming-/Performance-Tuning (NVIDIA, zram, MangoHud-RAPL, X3D).
# Setzt lib/common.sh und lib/packages.sh als gesourct voraus.

# _nvidia_gpu_present — 0 (true), wenn lspci eine NVIDIA-GPU meldet.
# lspci via $LSPCI übersteuerbar -> testbar ohne Hardware.
_nvidia_gpu_present() {
    "${LSPCI:-lspci}" 2>/dev/null | grep -Ei 'vga|3d|display' | grep -qi nvidia
}

# install_nvidia_packages_arch — installiert die NVIDIA-Pakete aus
# packages/arch-nvidia.txt, sofern eine NVIDIA-GPU vorhanden ist.
install_nvidia_packages_arch() {
    if ! _nvidia_gpu_present; then
        log_info "keine NVIDIA-GPU erkannt — NVIDIA-Pakete übersprungen"
        return 0
    fi
    local nvidia_list
    mapfile -t nvidia_list < <(parse_package_list "$DOTFILES_DIR/packages/arch-nvidia.txt")
    [[ "${#nvidia_list[@]}" -gt 0 ]] || return 0
    log_info "installiere NVIDIA-Pakete (${#nvidia_list[@]})"
    run sudo pacman -S --needed --noconfirm "${nvidia_list[@]}"
}

# _install_system_file <src> <dest> — kopiert eine Config nach /etc & Co.
# (root, 0644). Überspringt, wenn Ziel bereits identisch ist.
_install_system_file() {
    local src="$1" dest="$2"
    [[ -f "$src" ]] || { log_warn "$src fehlt — übersprungen"; return 0; }
    if cmp -s "$src" "$dest" 2>/dev/null; then
        log_ok "$dest ist aktuell"
        return 0
    fi
    run sudo install -Dm 644 "$src" "$dest"
    log_ok "$dest installiert"
}

# setup_gaming_system — System-Configs für Gaming/Performance:
# zram (Generator + sysctl-Tuning), MangoHud-RAPL-Leserechte, NVIDIA-modprobe.
setup_gaming_system() {
    log_info "richte Gaming-System-Tuning ein"

    _install_system_file "$DOTFILES_DIR/system/zram-generator.conf" \
        /etc/systemd/zram-generator.conf
    _install_system_file "$DOTFILES_DIR/system/sysctl.d/99-zram.conf" \
        /etc/sysctl.d/99-zram.conf
    # zram-Tuning sofort anwenden (greift sonst erst nach Reboot).
    run sudo sysctl -q -p /etc/sysctl.d/99-zram.conf

    _install_system_file "$DOTFILES_DIR/system/udev/51-rapl.rules" \
        /etc/udev/rules.d/51-rapl.rules

    if _nvidia_gpu_present; then
        _install_system_file "$DOTFILES_DIR/system/modprobe.d/nvidia.conf" \
            /etc/modprobe.d/nvidia.conf
    fi
}

# setup_x3d_gamemode — installiert den X3D-Umschalter für gamemode:
# /usr/local/bin/x3d-mode + sudoers-Drop-in (gamemoded läuft als User und
# braucht passwortloses sudo für den sysfs-Schreibzugriff). Nur auf Systemen
# mit amd_x3d_vcache-Treiber (X3D-CPU mit zwei CCDs).
setup_x3d_gamemode() {
    if [[ ! -d /sys/bus/platform/drivers/amd_x3d_vcache ]]; then
        log_info "kein AMD-X3D-vcache-Treiber — X3D-Umschaltung übersprungen"
        return 0
    fi

    run sudo install -Dm 755 "$DOTFILES_DIR/system/bin/x3d-mode" \
        /usr/local/bin/x3d-mode

    local dropin="/etc/sudoers.d/x3d-mode"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] sudoers-Drop-in für x3d-mode anlegen ($dropin)"
        return 0
    fi

    local tmp; tmp="$(mktemp)"
    printf '%s ALL=(root) NOPASSWD: /usr/local/bin/x3d-mode\n' "$USER" > "$tmp"
    # Syntax prüfen, bevor die Datei nach sudoers.d wandert (wie pwfeedback).
    if ! sudo visudo -cf "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        log_warn "sudoers-Drop-in ungültig — X3D-Umschaltung übersprungen"
        return 0
    fi
    sudo install -m 0440 -o root -g root "$tmp" "$dropin"
    rm -f "$tmp"
    log_ok "X3D-Umschaltung via gamemode eingerichtet ($dropin)"
}

# _apply_steam_desktop_edit <src> <dest> <wrapper> — generiert eine
# steam.desktop, deren Exec-Zeilen statt /usr/bin/steam den Wrapper starten.
# Reine Funktion -> testbar.
_apply_steam_desktop_edit() {
    local src="$1" dest="$2" wrapper="$3"
    sed "s|^Exec=/usr/bin/steam|Exec=$wrapper|" "$src" > "$dest"
}

# setup_steam_env — Steam über den Env-Wrapper starten lassen: bin/steam nach
# ~/.local/bin verlinken (steht vor /usr/bin im PATH) und steam.desktop nach
# ~/.local/share/applications überschreiben, damit auch Launcher-Starts den
# Wrapper nutzen. Der Wrapper lädt ~/.config/steam-env.conf (Symlink aus
# .config/) — alle Spiele erben die Gaming-Env-Defaults. Kein sudo nötig.
setup_steam_env() {
    local wrapper="$HOME/.local/bin/steam"

    run mkdir -p "$HOME/.local/bin"
    run ln -sfn "$DOTFILES_DIR/bin/steam" "$wrapper"

    local src="/usr/share/applications/steam.desktop"
    if [[ ! -f "$src" ]]; then
        log_info "steam.desktop nicht gefunden — Desktop-Override übersprungen"
        return 0
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] steam.desktop-Override mit Exec=$wrapper generieren"
        return 0
    fi
    mkdir -p "$HOME/.local/share/applications"
    _apply_steam_desktop_edit "$src" \
        "$HOME/.local/share/applications/steam.desktop" "$wrapper"
    log_ok "Steam-Env-Wrapper aktiv ($wrapper + steam.desktop-Override)"
}

# setup_gaming <distro> — Dispatcher. Der Hyprland/Gaming-Stack ist nur auf
# Arch paketiert; anderswo wird übersprungen.
setup_gaming() {
    case "$1" in
        arch)
            setup_gaming_system
            setup_x3d_gamemode
            setup_steam_env
            ;;
        *)  log_info "Gaming-Tuning nur auf Arch — übersprungen" ;;
    esac
}
