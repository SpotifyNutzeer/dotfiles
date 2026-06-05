#!/usr/bin/env bash
# fisher installieren und Plugins aus fish_plugins anwenden.
# Setzt lib/common.sh voraus und dass ~/.config/fish verlinkt ist.

setup_fisher() {
    if ! command -v fish >/dev/null 2>&1; then
        log_warn "fish nicht installiert, fisher übersprungen"
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] fisher installieren + 'fisher update' ausführen"
        return 0
    fi

    # fisher installieren, falls die Funktion nicht bekannt ist.
    # best-effort: ein Fehler (z.B. kein Netz) darf den Lauf nicht abbrechen.
    if ! fish -c 'functions -q fisher' 2>/dev/null; then
        log_info "installiere fisher"
        if ! fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'; then
            log_warn "fisher-Installation fehlgeschlagen — übersprungen"
            return 0
        fi
    fi

    # Plugins aus ~/.config/fish/fish_plugins anwenden.
    log_info "wende fish_plugins an (fisher update)"
    if fish -c 'fisher update'; then
        log_ok "fish-Plugins installiert"
    else
        log_warn "fisher update fehlgeschlagen — übersprungen"
    fi
}
