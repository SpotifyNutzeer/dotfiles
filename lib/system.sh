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
