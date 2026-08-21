#!/usr/bin/env bash
# systemd-User-Services verlinken + enablen.
# Setzt lib/common.sh und lib/symlinks.sh (link_item) voraus.
#
# Struktur im Repo (.config/systemd/user):
#   - Eigene Unit-Dateien liegen direkt als *.service vor (z.B. dac-keepalive).
#   - Welche Services aktiv sein sollen, steht in den *.target.wants/-Verzeichnissen
#     (eingecheckte enable-Symlinks, teils auf paket-bereitgestellte Units unter
#     /usr/lib/systemd/user). Daraus leiten wir die Aktivierungen ab.

# Services, die NICHT aktiviert werden sollen (z.B. nicht installierte Software).
SYSTEMD_SKIP=("sunshine.service")

_systemd_is_skipped() {
    local name="$1" s
    for s in "${SYSTEMD_SKIP[@]}"; do
        [[ "$name" == "$s" ]] && return 0
    done
    return 1
}

# _systemd_wanted_services <user-dir> — gibt die zu aktivierenden Service-Namen
# (eine pro Zeile, dedupliziert) aus allen *.target.wants/-Verzeichnissen aus.
_systemd_wanted_services() {
    local user_dir="$1" w
    for w in "$user_dir"/*.target.wants/*.service; do
        [[ -e "$w" || -L "$w" ]] || continue
        basename "$w"
    done | sort -u
}

# setup_systemd_services — verlinkt eigene Unit-Dateien und enabled die
# in den *.target.wants/ deklarierten Services (sunshine ausgenommen).
setup_systemd_services() {
    local src_dir="$DOTFILES_DIR/.config/systemd/user"
    local dst_dir="$HOME/.config/systemd/user"
    [[ -d "$src_dir" ]] || { log_warn "kein systemd/user-Verzeichnis, übersprungen"; return 0; }

    run mkdir -p "$dst_dir"

    # Eigene Unit-Dateien (direkt im user-Verzeichnis) verlinken, damit sie als
    # Units auffindbar sind. enable legt die wants-Symlinks danach selbst an.
    local svc name
    for svc in "$src_dir"/*.service; do
        [[ -e "$svc" ]] || continue
        name="$(basename "$svc")"
        link_item "$svc" "$dst_dir/$name"
    done

    run systemctl --user daemon-reload || log_warn "daemon-reload fehlgeschlagen — fahre fort"

    # Aktivierungen aus den *.target.wants/ ableiten. best-effort: ein fehlender
    # Unit (z.B. auf Debian/Fedora) oder fehlende User-Session darf den Lauf
    # nicht abbrechen.
    local wanted
    while IFS= read -r wanted; do
        [[ -n "$wanted" ]] || continue
        if _systemd_is_skipped "$wanted"; then
            log_warn "Service übersprungen (nicht installiert): $wanted"
            continue
        fi
        if run systemctl --user enable "$wanted"; then
            log_ok "enabled: $wanted"
        else
            log_warn "konnte nicht aktivieren (übersprungen): $wanted"
        fi
    done < <(_systemd_wanted_services "$src_dir")
}
