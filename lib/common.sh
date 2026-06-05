#!/usr/bin/env bash
# Gemeinsame Helfer. Wird von install.sh und den Modulen gesourct.
# DRY_RUN wird von install.sh gesetzt (0 oder 1).
: "${DRY_RUN:=0}"

log_info()  { printf '\033[34m::\033[0m %s\n' "$*" >&2; }
log_ok()    { printf '\033[32mok\033[0m %s\n' "$*" >&2; }
log_warn()  { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
log_error() { printf '\033[31mxx\033[0m %s\n' "$*" >&2; }

# run <cmd...> — führt cmd aus oder zeigt es nur bei DRY_RUN.
run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '\033[36m[dry-run]\033[0m %s\n' "$*" >&2
        return 0
    fi
    "$@"
}

# confirm <prompt> — ja/nein, Default nein. Gibt 0 bei ja zurück.
confirm() {
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" == "y" || "$reply" == "Y" ]]
}

# detect_distro — setzt globale Variable DETECTED_DISTRO.
# Liest aus $OS_RELEASE (Default /etc/os-release), testbar.
detect_distro() {
    local os_release="${OS_RELEASE:-/etc/os-release}"
    DETECTED_DISTRO="unknown"
    [[ -r "$os_release" ]] || return 0

    local id id_like
    id="$(. "$os_release" 2>/dev/null; printf '%s' "${ID:-}")"
    id_like="$(. "$os_release" 2>/dev/null; printf '%s' "${ID_LIKE:-}")"

    case "$id" in
        arch)            DETECTED_DISTRO="arch" ;;
        debian|ubuntu)   DETECTED_DISTRO="debian" ;;
        fedora)          DETECTED_DISTRO="fedora" ;;
        *)
            case " $id_like " in
                *" arch "*)            DETECTED_DISTRO="arch" ;;
                *" debian "*|*" ubuntu "*) DETECTED_DISTRO="debian" ;;
                *" fedora "*|*" rhel "*)   DETECTED_DISTRO="fedora" ;;
            esac
            ;;
    esac
}
