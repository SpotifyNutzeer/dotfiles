#!/usr/bin/env bash
# Desktop-App-Integrationen, die nicht ins Gaming-Setup gehören.
# Muster wie der Steam-Env-Wrapper (lib/gaming.sh, setup_steam_env): Wrapper nach
# ~/.local/bin (steht vor /usr/bin im PATH) + .desktop-Override nach
# ~/.local/share/applications, dessen Exec auf den Wrapper umgebogen wird und so
# alle Upstream-Flags erbt. Setzt lib/common.sh voraus (run, log_*, DRY_RUN).

# _apply_tidaluna_desktop_edit <src> <dest> <wrapper> — generiert eine
# tidal-hifi.desktop, deren Exec-Zeilen statt 'tidal-hifi' den Wrapper starten.
# Erbt damit alle Upstream-Flags (Wayland etc.) automatisch. Reine Funktion -> testbar.
_apply_tidaluna_desktop_edit() {
    local src="$1" dest="$2" wrapper="$3"
    sed "s|^Exec=tidal-hifi\b|Exec=$wrapper|" "$src" > "$dest"
}

# setup_tidaluna_env — TidaLuna (tidal-hifi) über den Wrapper starten lassen:
# bin/tidal-hifi nach ~/.local/bin verlinken (steht vor /usr/bin im PATH, greift
# damit auch bei Terminal-Starts) und tidal-hifi.desktop nach
# ~/.local/share/applications überschreiben, damit auch Launcher-Starts den
# Wrapper nutzen. Der Wrapper nagelt Electron auf gnome-libsecret fest, damit der
# Plugin-Permission-Trust-Store persistiert (siehe bin/tidal-hifi). Kein sudo nötig.
# No-op, falls tidal-hifi gar nicht installiert ist (.desktop fehlt).
setup_tidaluna_env() {
    local wrapper="$HOME/.local/bin/tidal-hifi"

    run mkdir -p "$HOME/.local/bin"
    run ln -sfn "$DOTFILES_DIR/bin/tidal-hifi" "$wrapper"

    local src="/usr/share/applications/tidal-hifi.desktop"
    if [[ ! -f "$src" ]]; then
        log_info "tidal-hifi.desktop nicht gefunden — Desktop-Override übersprungen"
        return 0
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] tidal-hifi.desktop-Override mit Exec=$wrapper generieren"
        return 0
    fi
    mkdir -p "$HOME/.local/share/applications"
    _apply_tidaluna_desktop_edit "$src" \
        "$HOME/.local/share/applications/tidal-hifi.desktop" "$wrapper"
    log_ok "TidaLuna-Wrapper aktiv ($wrapper + tidal-hifi.desktop-Override)"
}
