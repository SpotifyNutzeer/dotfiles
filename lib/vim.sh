#!/usr/bin/env bash
# vim-plug installieren und die Plugins aus der .vimrc installieren.
# Setzt lib/common.sh voraus und dass ~/.vimrc verlinkt ist. Braucht curl + git.

setup_vim_plug() {
    if ! command -v vim >/dev/null 2>&1; then
        log_warn "vim nicht installiert, vim-plug übersprungen"
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] vim-plug installieren + ':PlugInstall --sync'"
        return 0
    fi

    local plug="$HOME/.vim/autoload/plug.vim"
    if [[ ! -f "$plug" ]]; then
        log_info "installiere vim-plug"
        if ! curl -fLo "$plug" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
            log_warn "vim-plug-Installation fehlgeschlagen — übersprungen"
            return 0
        fi
    fi

    # --sync: PlugInstall läuft synchron fertig, bevor vim beendet wird.
    log_info "installiere vim-Plugins (PlugInstall)"
    if vim +'PlugInstall --sync' +qall >/dev/null 2>&1; then
        log_ok "vim-Plugins installiert"
    else
        log_warn "PlugInstall fehlgeschlagen — übersprungen"
    fi
}
