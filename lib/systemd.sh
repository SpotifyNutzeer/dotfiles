#!/usr/bin/env bash
# systemd-User-Services verlinken + enablen.
# Setzt lib/common.sh und lib/symlinks.sh (link_item) voraus.

# Services, die NICHT aktiviert werden sollen (z.B. nicht installierte Software).
SYSTEMD_SKIP=("sunshine.service")

_systemd_is_skipped() {
    local name="$1" s
    for s in "${SYSTEMD_SKIP[@]}"; do
        [[ "$name" == "$s" ]] && return 0
    done
    return 1
}

# setup_systemd_services — verlinkt *.service einzeln und enabled sie.
setup_systemd_services() {
    local src_dir="$DOTFILES_DIR/.config/systemd/user"
    local dst_dir="$HOME/.config/systemd/user"
    [[ -d "$src_dir" ]] || { log_warn "kein systemd/user-Verzeichnis, übersprungen"; return 0; }

    run mkdir -p "$dst_dir"

    local svc name
    for svc in "$src_dir"/*.service; do
        [[ -e "$svc" ]] || continue
        name="$(basename "$svc")"
        if _systemd_is_skipped "$name"; then
            log_warn "Service übersprungen (nicht installiert): $name"
            continue
        fi
        link_item "$svc" "$dst_dir/$name"
    done

    run systemctl --user daemon-reload

    for svc in "$src_dir"/*.service; do
        [[ -e "$svc" ]] || continue
        name="$(basename "$svc")"
        _systemd_is_skipped "$name" && continue
        run systemctl --user enable "$name"
        log_ok "enabled: $name"
    done
}
