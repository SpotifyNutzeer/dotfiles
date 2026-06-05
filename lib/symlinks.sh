#!/usr/bin/env bash
# Symlink-Verwaltung mit interaktivem Konflikt-Handling.
# Setzt lib/common.sh voraus. Nutzt globale: BACKUP_DIR, CONFLICT_ALL.

: "${CONFLICT_ALL:=}"   # gesetzt auf "backup"/"skip"/"overwrite" => für alle anwenden

# _ensure_backup_dir — setzt globale BACKUP_DIR lazy (ein Verzeichnis pro Lauf).
# WICHTIG: NICHT via $(...) aufrufen — das liefe in einer Subshell und die
# Zuweisung käme nie im Parent an. Direkt aufrufen, dann $BACKUP_DIR nutzen.
_ensure_backup_dir() {
    : "${BACKUP_DIR:=$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)}"
    [[ "$DRY_RUN" -eq 1 ]] || mkdir -p "$BACKUP_DIR"
}

# _resolve_conflict <dst> — fragt interaktiv (sofern CONFLICT_ALL leer) und
# gibt die Aktion aus: backup | skip | overwrite.
_resolve_conflict() {
    local dst="$1"
    if [[ -n "$CONFLICT_ALL" ]]; then
        printf '%s' "$CONFLICT_ALL"
        return 0
    fi
    local reply=""
    # `|| true`: ohne TTY (EOF) würde read non-zero liefern und unter
    # `set -e` (Orchestrator) den Lauf abbrechen. Leeres reply -> Default Backup.
    read -r -p "Konflikt bei $dst — [B]ackup / [s]kip / [o]verwrite / [A]lle backuppen: " reply || true
    case "$reply" in
        s|S) printf 'skip' ;;
        o|O) printf 'overwrite' ;;
        a|A) CONFLICT_ALL="backup"; printf 'backup' ;;
        *)   printf 'backup' ;;   # Default
    esac
}

# link_item <src> <dst> — verlinkt src nach dst mit Konflikt-Handling.
link_item() {
    local src="$1" dst="$2"

    # Bereits korrekter Symlink? -> nichts tun (idempotent).
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        log_ok "bereits verlinkt: $dst"
        return 0
    fi

    # Ziel im Weg (Datei, Verzeichnis oder falscher Symlink)?
    if [[ -e "$dst" || -L "$dst" ]]; then
        local action
        action="$(_resolve_conflict "$dst")"
        case "$action" in
            skip)
                log_warn "übersprungen: $dst"
                return 0
                ;;
            overwrite)
                run rm -rf "$dst"
                ;;
            backup)
                _ensure_backup_dir
                # Basename-Kollision vermeiden (zwei Konflikte mit gleichem
                # Namen würden sonst dasselbe Backup-Ziel überschreiben).
                local target="$BACKUP_DIR/$(basename "$dst")" n=1
                while [[ -e "$target" || -L "$target" ]]; do
                    target="$BACKUP_DIR/$(basename "$dst").$n"
                    n=$((n + 1))
                done
                run mv "$dst" "$target"
                log_info "gesichert nach $target"
                ;;
        esac
    fi

    run mkdir -p "$(dirname "$dst")"
    run ln -s "$src" "$dst"
    log_ok "verlinkt: $dst -> $src"
}

# link_dotfiles — verlinkt .config/* (außer systemd) und .vimrc.
# Erwartet DOTFILES_DIR gesetzt.
link_dotfiles() {
    local config_src="$DOTFILES_DIR/.config"
    local entry name
    for entry in "$config_src"/*; do
        [[ -e "$entry" ]] || continue
        name="$(basename "$entry")"
        [[ "$name" == "systemd" ]] && continue   # Sonderbehandlung in systemd.sh
        link_item "$entry" "$HOME/.config/$name"
    done
    link_item "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
}
