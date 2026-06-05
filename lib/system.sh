#!/usr/bin/env bash
# System-weite Konfiguration (sudo). Setzt lib/common.sh voraus.

# configure_sudo_pwfeedback — aktiviert Passwort-Feedback (Sternchen beim Tippen)
# über ein Drop-in unter /etc/sudoers.d/. Die Datei wird mit visudo validiert,
# BEVOR sie aktiv wird — eine fehlerhafte sudoers-Datei kann sudo unbrauchbar
# machen. Idempotent (install überschreibt die Drop-in bei erneutem Lauf).
configure_sudo_pwfeedback() {
    local dropin="/etc/sudoers.d/pwfeedback"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] sudo Passwort-Feedback aktivieren ($dropin)"
        return 0
    fi

    local tmp; tmp="$(mktemp)"
    printf 'Defaults pwfeedback\n' > "$tmp"

    # Syntax prüfen, bevor die Datei nach sudoers.d wandert.
    if ! sudo visudo -cf "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        log_warn "sudoers-Drop-in ungültig — Passwort-Feedback übersprungen"
        return 0
    fi

    sudo install -m 0440 -o root -g root "$tmp" "$dropin"
    rm -f "$tmp"
    log_ok "sudo Passwort-Feedback aktiviert ($dropin)"
}

# set_default_shell_fish — setzt die Login-Shell des aktuellen Users auf fish.
# Idempotent; überspringt, wenn fish fehlt oder schon Login-Shell ist.
set_default_shell_fish() {
    local fish_path
    fish_path="$(command -v fish 2>/dev/null)" \
        || { log_warn "fish nicht gefunden — Shell-Wechsel übersprungen"; return 0; }

    local current
    current="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current" == "$fish_path" ]]; then
        log_ok "Login-Shell ist bereits fish"
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] /etc/shells ergänzen + chsh -s $fish_path $USER"
        return 0
    fi

    # fish muss in /etc/shells stehen, sonst lehnt chsh ab.
    grep -qx "$fish_path" /etc/shells 2>/dev/null \
        || sudo sh -c "echo '$fish_path' >> /etc/shells"
    sudo chsh -s "$fish_path" "$USER"
    log_ok "Login-Shell auf fish gesetzt ($fish_path)"
}
