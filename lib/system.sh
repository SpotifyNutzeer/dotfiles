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

# _apply_askpass_edit <conf> <helper> — trägt 'Path askpass <helper>' in die
# gegebene sudo.conf ein, sofern noch kein askpass konfiguriert ist.
# Idempotent, reine Funktion -> testbar ohne sudo.
_apply_askpass_edit() {
    local conf="$1" helper="$2"
    grep -q '^Path askpass ' "$conf" 2>/dev/null && return 0
    printf 'Path askpass %s\n' "$helper" >> "$conf"
}

# configure_sudo_askpass — richtet ksshaskpass als grafischen Askpass-Helper
# für sudo ein (/etc/sudo.conf). Damit funktioniert 'sudo -A' auch ohne
# Terminal (z.B. aus GUI-Tools oder nicht-interaktiven Shells heraus).
configure_sudo_askpass() {
    local conf="/etc/sudo.conf" helper="/usr/bin/ksshaskpass"

    if [[ ! -x "$helper" ]]; then
        log_info "ksshaskpass nicht installiert — sudo askpass übersprungen"
        return 0
    fi
    if grep -q '^Path askpass ' "$conf" 2>/dev/null; then
        log_ok "sudo askpass bereits konfiguriert"
        return 0
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] 'Path askpass $helper' in $conf eintragen"
        return 0
    fi

    # Funktion in eine root-Shell exportieren (Muster wie _apply_pacman_edits).
    sudo bash -c "$(declare -f _apply_askpass_edit); _apply_askpass_edit '$conf' '$helper'"
    log_ok "sudo askpass konfiguriert ($helper) — grafischer Dialog via 'sudo -A'"
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
    if sudo chsh -s "$fish_path" "$USER"; then
        log_ok "Login-Shell auf fish gesetzt ($fish_path) — gilt ab nächstem Login"
    else
        log_warn "chsh fehlgeschlagen — Login-Shell nicht geändert"
    fi
}
