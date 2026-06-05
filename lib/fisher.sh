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
    if ! fish -c 'functions -q fisher' 2>/dev/null; then
        log_info "installiere fisher"
        fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
    fi

    # Plugins aus ~/.config/fish/fish_plugins anwenden.
    log_info "wende fish_plugins an (fisher update)"
    fish -c 'fisher update'
    log_ok "fish-Plugins installiert"
}
