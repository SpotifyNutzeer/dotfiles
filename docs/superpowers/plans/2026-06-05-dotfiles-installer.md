# Dotfiles-Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein modulares Bash-Script, das nach einer Neuinstallation Pakete installiert, Dotfiles per Symlink verknüpft, systemd-User-Services aktiviert und fish-Plugins installiert (voll für Arch, best-effort für Debian/Fedora).

**Architecture:** Ein Orchestrator `install.sh` lädt Module aus `lib/` (common, packages, symlinks, systemd, fisher) und ruft sie in fester Reihenfolge auf. Paketlisten liegen als reine Textdateien in `packages/`. Reine Funktionen werden mit einem abhängigkeitsfreien Bash-Test-Harness (`tests/`) per TDD getestet; Seiteneffekt-Installation wird über `--dry-run` verifiziert.

**Tech Stack:** Bash (`set -euo pipefail`), `/etc/os-release` für Distro-Erkennung, `pacman`/`yay`/`apt-get`/`dnf`, `systemctl --user`, `fisher`. Tests: reines Bash-Harness, keine externen Abhängigkeiten.

---

## File Structure

- `install.sh` — Orchestrator: Args parsen, Distro erkennen, Module in Reihenfolge aufrufen, Abschluss-Hinweise.
- `lib/common.sh` — Logging, `confirm()`, `detect_distro()`, Pfad-Variablen, `DRY_RUN`-Handling, `run()`-Wrapper.
- `lib/packages.sh` — Listen parsen + Installation je Distro (pacman/AUR-Bootstrap, apt, dnf).
- `lib/symlinks.sh` — `link_item()`, Konflikt-Handling, `link_dotfiles()`.
- `lib/systemd.sh` — `*.service` verlinken + enablen (sunshine ausgenommen).
- `lib/fisher.sh` — fisher installieren + Plugins aus `fish_plugins`.
- `packages/arch-pacman.txt`, `packages/arch-aur.txt`, `packages/debian.txt`, `packages/fedora.txt` — Paketlisten.
- `tests/helpers.sh` — `assert_*`-Funktionen + Mini-Runner.
- `tests/test_common.sh`, `tests/test_packages.sh`, `tests/test_symlinks.sh` — Unit-Tests.
- `tests/run.sh` — führt alle `test_*.sh` aus.

---

## Task 1: Test-Harness

**Files:**
- Create: `tests/helpers.sh`
- Create: `tests/run.sh`

- [ ] **Step 1: Test-Helpers schreiben**

Create `tests/helpers.sh`:

```bash
#!/usr/bin/env bash
# Abhängigkeitsfreies Test-Harness. Quelle dies in test_*.sh-Dateien.

TESTS_RUN=0
TESTS_FAILED=0

_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  \033[31mFAIL\033[0m %s\n' "$1" >&2
}

_pass() {
    printf '  \033[32mok\033[0m   %s\n' "$1"
}

assert_eq() {
    # assert_eq <actual> <expected> <message>
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$1" == "$2" ]]; then
        _pass "$3"
    else
        _fail "$3 (got '$1', expected '$2')"
    fi
}

assert_symlink_to() {
    # assert_symlink_to <link> <target> <message>
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -L "$1" && "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]; then
        _pass "$3"
    else
        _fail "$3 ('$1' is not a symlink to '$2')"
    fi
}

assert_contains() {
    # assert_contains <haystack> <needle> <message>
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$1" == *"$2"* ]]; then
        _pass "$3"
    else
        _fail "$3 ('$1' does not contain '$2')"
    fi
}

finish() {
    printf '\n%d run, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED"
    [[ "$TESTS_FAILED" -eq 0 ]]
}
```

- [ ] **Step 2: Test-Runner schreiben**

Create `tests/run.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

rc=0
for t in test_*.sh; do
    [[ -e "$t" ]] || continue
    printf '\033[1m== %s ==\033[0m\n' "$t"
    bash "$t" || rc=1
done
exit "$rc"
```

- [ ] **Step 3: Ausführbar machen und leeren Lauf prüfen**

Run:
```bash
chmod +x tests/run.sh && bash tests/run.sh
```
Expected: Läuft ohne Fehler durch (keine `test_*.sh` außer evtl. später), Exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/helpers.sh tests/run.sh
git commit -m "test: add dependency-free bash test harness"
```

---

## Task 2: lib/common.sh — Logging, Pfade, Distro-Erkennung

**Files:**
- Create: `lib/common.sh`
- Test: `tests/test_common.sh`

- [ ] **Step 1: Failing test für detect_distro schreiben**

Create `tests/test_common.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Arch
printf 'ID=arch\n' > "$tmp/arch"
OS_RELEASE="$tmp/arch" detect_distro
assert_eq "$DETECTED_DISTRO" "arch" "detect_distro erkennt arch"

# Debian via ID
printf 'ID=debian\n' > "$tmp/debian"
OS_RELEASE="$tmp/debian" detect_distro
assert_eq "$DETECTED_DISTRO" "debian" "detect_distro erkennt debian"

# Ubuntu via ID_LIKE
printf 'ID=ubuntu\nID_LIKE=debian\n' > "$tmp/ubuntu"
OS_RELEASE="$tmp/ubuntu" detect_distro
assert_eq "$DETECTED_DISTRO" "debian" "detect_distro mappt ubuntu auf debian"

# Fedora
printf 'ID=fedora\n' > "$tmp/fedora"
OS_RELEASE="$tmp/fedora" detect_distro
assert_eq "$DETECTED_DISTRO" "fedora" "detect_distro erkennt fedora"

# Unbekannt
printf 'ID=plan9\n' > "$tmp/unknown"
OS_RELEASE="$tmp/unknown" detect_distro
assert_eq "$DETECTED_DISTRO" "unknown" "detect_distro fällt auf unknown zurück"

finish
```

- [ ] **Step 2: Test ausführen, Fehlschlag verifizieren**

Run: `bash tests/test_common.sh`
Expected: FAIL — `lib/common.sh` existiert nicht (source schlägt fehl).

- [ ] **Step 3: lib/common.sh implementieren**

Create `lib/common.sh`:

```bash
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
```

- [ ] **Step 4: Test ausführen, Erfolg verifizieren**

Run: `bash tests/test_common.sh`
Expected: PASS — alle 5 Assertions ok.

- [ ] **Step 5: Commit**

```bash
git add lib/common.sh tests/test_common.sh
git commit -m "feat: add common helpers and distro detection"
```

---

## Task 3: Paketlisten + Parsing

**Files:**
- Create: `packages/arch-pacman.txt`
- Create: `packages/arch-aur.txt`
- Create: `packages/debian.txt`
- Create: `packages/fedora.txt`
- Create: `lib/packages.sh` (nur Parsing in dieser Task)
- Test: `tests/test_packages.sh`

- [ ] **Step 1: Paketlisten anlegen**

Create `packages/arch-pacman.txt`:
```
# Shell & Terminals
fish
kitty
alacritty
tmux
starship
htop
vim
# Wayland / Hyprland
hyprland
hyprpolkitagent
# Audio
pipewire
pipewire-pulse
wireplumber
sox
# Tools
rofi-wayland
cava
mangohud
brightnessctl
playerctl
# Fonts & Icons
ttf-jetbrains-mono-nerd
papirus-icon-theme
# Basis (u.a. für AUR-Bootstrap)
git
curl
base-devel
```

Create `packages/arch-aur.txt`:
```
quickshell
papirus-folders-catppuccin-git
```

Create `packages/debian.txt`:
```
# Best-effort. Vieles (hyprland, quickshell, papirus-folders-catppuccin)
# ist auf Debian nicht paketiert und wird beim Lauf nur gewarnt.
fish
kitty
alacritty
tmux
htop
vim
pipewire
pipewire-pulse
wireplumber
sox
rofi
cava
mangohud
brightnessctl
playerctl
fonts-jetbrains-mono
papirus-icon-theme
git
curl
# nicht in Debian-Repos: hyprland hyprpolkitagent quickshell starship papirus-folders-catppuccin-git
```

Create `packages/fedora.txt`:
```
# Best-effort. Vieles (quickshell, papirus-folders-catppuccin) fehlt und
# wird beim Lauf nur gewarnt. hyprland ist in neueren Fedora-Repos verfügbar.
fish
kitty
alacritty
tmux
starship
htop
vim
hyprland
pipewire
pipewire-pulse
wireplumber
sox
rofi-wayland
cava
mangohud
brightnessctl
playerctl
jetbrains-mono-fonts
papirus-icon-theme
git
curl
# nicht sicher verfügbar: hyprpolkitagent quickshell papirus-folders-catppuccin-git
```

- [ ] **Step 2: Failing test für parse_package_list schreiben**

Create `tests/test_packages.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/packages.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/list.txt" <<'EOF'
# ein Kommentar
fish

kitty
  vim
EOF

result="$(parse_package_list "$tmp/list.txt" | tr '\n' ' ')"
assert_eq "$result" "fish kitty vim " "parse_package_list ignoriert Kommentare/Leerzeilen, trimmt"

empty="$(parse_package_list "$tmp/does-not-exist.txt"; echo done)"
assert_eq "$empty" "done" "parse_package_list verträgt fehlende Datei"

finish
```

- [ ] **Step 3: Test ausführen, Fehlschlag verifizieren**

Run: `bash tests/test_packages.sh`
Expected: FAIL — `parse_package_list` nicht definiert.

- [ ] **Step 4: parse_package_list implementieren**

Create `lib/packages.sh`:

```bash
#!/usr/bin/env bash
# Paket-Parsing und -Installation. Setzt lib/common.sh als gesourct voraus.

# parse_package_list <file> — gibt eine Paket pro Zeile aus,
# ohne Kommentare (#...), ohne Leerzeilen, getrimmt.
parse_package_list() {
    local file="$1"
    [[ -r "$file" ]] || return 0
    while IFS= read -r line; do
        line="${line%%#*}"                       # Kommentar ab # entfernen
        line="${line#"${line%%[![:space:]]*}"}"  # links trimmen
        line="${line%"${line##*[![:space:]]}"}"  # rechts trimmen
        [[ -n "$line" ]] && printf '%s\n' "$line"
    done < "$file"
}
```

- [ ] **Step 5: Test ausführen, Erfolg verifizieren**

Run: `bash tests/test_packages.sh`
Expected: PASS — beide Assertions ok.

- [ ] **Step 6: Commit**

```bash
git add packages/ lib/packages.sh tests/test_packages.sh
git commit -m "feat: add package lists and list parser"
```

---

## Task 4: lib/symlinks.sh — Verlinkung + Konflikt-Handling

**Files:**
- Create: `lib/symlinks.sh`
- Test: `tests/test_symlinks.sh`

- [ ] **Step 1: Failing tests für link_item schreiben**

Create `tests/test_symlinks.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/symlinks.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

src="$tmp/repo/foo"
mkdir -p "$src"
printf 'hi\n' > "$src/file"

# Fall 1: Ziel existiert nicht -> Symlink wird angelegt
dst="$tmp/home/foo"
mkdir -p "$tmp/home"
CONFLICT_ALL="" link_item "$src" "$dst"
assert_symlink_to "$dst" "$src" "link_item legt fehlenden Symlink an"

# Fall 2: Ziel ist bereits korrekter Symlink -> idempotent, kein Fehler
CONFLICT_ALL="" link_item "$src" "$dst"
assert_symlink_to "$dst" "$src" "link_item ist idempotent bei korrektem Symlink"

# Fall 3: Konflikt, CONFLICT_ALL=backup -> altes Ziel wird gesichert, Symlink gesetzt
dst2="$tmp/home/bar"
mkdir -p "$tmp/repo/bar"
printf 'realdata\n' > "$dst2"   # echte Datei im Weg
BACKUP_DIR="$tmp/backup" CONFLICT_ALL="backup" link_item "$tmp/repo/bar" "$dst2"
assert_symlink_to "$dst2" "$tmp/repo/bar" "link_item setzt Symlink nach Backup"
assert_eq "$(cat "$tmp/backup/bar")" "realdata" "link_item sichert Konflikt-Datei ins Backup"

finish
```

- [ ] **Step 2: Test ausführen, Fehlschlag verifizieren**

Run: `bash tests/test_symlinks.sh`
Expected: FAIL — `link_item` nicht definiert.

- [ ] **Step 3: lib/symlinks.sh implementieren**

Create `lib/symlinks.sh`:

```bash
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
    local reply
    read -r -p "Konflikt bei $dst — [B]ackup / [s]kip / [o]verwrite / [A]lle backuppen: " reply
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
                run mv "$dst" "$BACKUP_DIR/$(basename "$dst")"
                log_info "gesichert nach $BACKUP_DIR/$(basename "$dst")"
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
```

- [ ] **Step 4: Test ausführen, Erfolg verifizieren**

Run: `bash tests/test_symlinks.sh`
Expected: PASS — alle 4 Assertions ok.

- [ ] **Step 5: Commit**

```bash
git add lib/symlinks.sh tests/test_symlinks.sh
git commit -m "feat: add symlink linking with conflict handling"
```

---

## Task 5: lib/systemd.sh — User-Services

**Files:**
- Create: `lib/systemd.sh`

Hinweis: Diese Funktion hat Seiteneffekte (`systemctl --user`) und wird über
`--dry-run` verifiziert, nicht per Unit-Test.

- [ ] **Step 1: lib/systemd.sh implementieren**

Create `lib/systemd.sh`:

```bash
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
```

- [ ] **Step 2: Verifizieren, dass die Datei syntaktisch lädt**

Run:
```bash
bash -n lib/systemd.sh && echo "syntax ok"
```
Expected: `syntax ok`

- [ ] **Step 3: Commit**

```bash
git add lib/systemd.sh
git commit -m "feat: add systemd user service setup"
```

---

## Task 6: lib/fisher.sh — fish-Plugins

**Files:**
- Create: `lib/fisher.sh`

Hinweis: Seiteneffekte (`fish`/`fisher`); Verifikation über `--dry-run` und
Syntax-Check.

- [ ] **Step 1: lib/fisher.sh implementieren**

Create `lib/fisher.sh`:

```bash
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
```

- [ ] **Step 2: Syntax-Check**

Run:
```bash
bash -n lib/fisher.sh && echo "syntax ok"
```
Expected: `syntax ok`

- [ ] **Step 3: Commit**

```bash
git add lib/fisher.sh
git commit -m "feat: add fisher plugin setup"
```

---

## Task 7: lib/packages.sh — Installation je Distro

**Files:**
- Modify: `lib/packages.sh` (Installationsfunktionen ergänzen)

Hinweis: Seiteneffekte (`sudo pacman` etc.); Verifikation über `--dry-run` in Task 8.

- [ ] **Step 1: Installationsfunktionen an lib/packages.sh anhängen**

Append to `lib/packages.sh`:

```bash

# _ensure_yay — stellt sicher, dass yay verfügbar ist (sonst Bootstrap aus AUR).
_ensure_yay() {
    command -v yay >/dev/null 2>&1 && return 0
    log_info "yay nicht gefunden — bootstrappe aus AUR"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] git clone yay + makepkg -si"
        return 0
    fi
    local tmp; tmp="$(mktemp -d)"
    if git clone https://aur.archlinux.org/yay.git "$tmp/yay" \
        && ( cd "$tmp/yay" && makepkg -si --noconfirm ); then
        rm -rf "$tmp"
        return 0
    fi
    rm -rf "$tmp"
    log_warn "yay-Bootstrap fehlgeschlagen — AUR-Pakete werden übersprungen"
    return 1
}

# install_packages_arch
install_packages_arch() {
    local pacman_list aur_list
    mapfile -t pacman_list < <(parse_package_list "$DOTFILES_DIR/packages/arch-pacman.txt")
    mapfile -t aur_list < <(parse_package_list "$DOTFILES_DIR/packages/arch-aur.txt")

    if [[ "${#pacman_list[@]}" -gt 0 ]]; then
        log_info "installiere pacman-Pakete (${#pacman_list[@]})"
        run sudo pacman -S --needed --noconfirm "${pacman_list[@]}"
    fi

    if [[ "${#aur_list[@]}" -gt 0 ]]; then
        if _ensure_yay; then
            log_info "installiere AUR-Pakete (${#aur_list[@]})"
            run yay -S --needed --noconfirm "${aur_list[@]}"
        fi
    fi
}

# _install_best_effort <installer-cmd...> < liste : versucht jedes Paket einzeln,
# warnt bei Fehlern statt abzubrechen. Pakete kommen über stdin (eine pro Zeile).
_install_best_effort() {
    local pkg
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        if run "$@" "$pkg"; then
            :
        else
            log_warn "Paket nicht installierbar (übersprungen): $pkg"
        fi
    done
}

# install_packages_debian
install_packages_debian() {
    run sudo apt-get update
    parse_package_list "$DOTFILES_DIR/packages/debian.txt" \
        | _install_best_effort sudo apt-get install -y
}

# install_packages_fedora
install_packages_fedora() {
    parse_package_list "$DOTFILES_DIR/packages/fedora.txt" \
        | _install_best_effort sudo dnf install -y
}

# install_packages <distro> — Dispatcher.
install_packages() {
    case "$1" in
        arch)   install_packages_arch ;;
        debian) install_packages_debian ;;
        fedora) install_packages_fedora ;;
        *)      log_warn "unbekannte Distro '$1' — Paketinstallation übersprungen" ;;
    esac
}
```

- [ ] **Step 2: Bestehende Tests laufen weiter (Parsing unverändert)**

Run: `bash tests/test_packages.sh`
Expected: PASS — die Parsing-Tests aus Task 3 bleiben grün.

- [ ] **Step 3: Syntax-Check**

Run: `bash -n lib/packages.sh && echo "syntax ok"`
Expected: `syntax ok`

- [ ] **Step 4: Commit**

```bash
git add lib/packages.sh
git commit -m "feat: add per-distro package installation"
```

---

## Task 8: install.sh — Orchestrator

**Files:**
- Create: `install.sh`

- [ ] **Step 1: install.sh implementieren**

Create `install.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

DRY_RUN=0
NO_PACKAGES=0
DISTRO_OVERRIDE=""

usage() {
    cat <<EOF
Usage: ./install.sh [Optionen]

  --no-packages        Nur Symlinks/systemd/fisher, keine Paketinstallation
  --dry-run            Aktionen nur anzeigen, nichts ausführen
  --distro <name>      Distro-Erkennung übersteuern (arch|debian|fedora)
  -h, --help           Diese Hilfe
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-packages) NO_PACKAGES=1; shift ;;
        --dry-run)     DRY_RUN=1; shift ;;
        --distro)      DISTRO_OVERRIDE="${2:-}"; shift 2 ;;
        -h|--help)     usage; exit 0 ;;
        *)             echo "Unbekannte Option: $1" >&2; usage; exit 1 ;;
    esac
done
export DRY_RUN

# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/packages.sh"
source "$DOTFILES_DIR/lib/symlinks.sh"
source "$DOTFILES_DIR/lib/systemd.sh"
source "$DOTFILES_DIR/lib/fisher.sh"

# Distro bestimmen
if [[ -n "$DISTRO_OVERRIDE" ]]; then
    DETECTED_DISTRO="$DISTRO_OVERRIDE"
else
    detect_distro
fi
log_info "Distro: $DETECTED_DISTRO"
[[ "$DRY_RUN" -eq 1 ]] && log_info "DRY-RUN aktiv — es wird nichts verändert"

if [[ "$DETECTED_DISTRO" == "unknown" ]]; then
    log_error "Distro nicht erkannt. Nutze --distro <arch|debian|fedora>."
    exit 1
fi

# 1. Pakete
if [[ "$NO_PACKAGES" -eq 1 ]]; then
    log_info "Paketinstallation übersprungen (--no-packages)"
else
    install_packages "$DETECTED_DISTRO"
fi

# 2. Symlinks
log_info "verlinke Dotfiles"
link_dotfiles

# 3. systemd
log_info "richte systemd-User-Services ein"
setup_systemd_services

# 4. fisher
log_info "richte fish-Plugins ein"
setup_fisher

# 5. Abschluss-Hinweise
cat >&2 <<'EOF'

────────────────────────────────────────────────────────
Fertig. Hinweise:

• Papirus-Ordnerfarbe (optional):
    papirus-folders -C cat-mocha-teal --theme Papirus-Dark

• rodecaster-tidal-bridge ist NICHT Teil dieses Installers.
  Eigenes Projekt: https://github.com/SpotifyNutzeer/rodecaster-tidal-bridge
  Manuell klonen/einrichten (config.toml wurde mitverlinkt).
────────────────────────────────────────────────────────
EOF
```

- [ ] **Step 2: Ausführbar machen + Syntax-Check**

Run:
```bash
chmod +x install.sh && bash -n install.sh && echo "syntax ok"
```
Expected: `syntax ok`

- [ ] **Step 3: Dry-Run-Smoke-Test auf aktuellem System**

Run:
```bash
./install.sh --dry-run
```
Expected: Ausgabe zeigt erkannte Distro (`arch`), `[dry-run]`-Zeilen für pacman/yay-Pakete, geplante Symlinks für alle `.config`-Einträge + `.vimrc`, systemd-Verlinkung/enable (ohne sunshine), fisher-Schritt, und die Abschluss-Hinweise. Es darf KEINE echte Datei/Symlink entstehen und kein Service enabled werden.

- [ ] **Step 4: Dry-Run mit --no-packages und --distro prüfen**

Run:
```bash
./install.sh --dry-run --no-packages
./install.sh --dry-run --distro debian
```
Expected: Erster Lauf überspringt Paketinstallation; zweiter zeigt apt-Pfad (best-effort) statt pacman.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh orchestrator"
```

---

## Task 9: Gesamttest + README-Hinweis

**Files:**
- Modify: `tests/run.sh` (bereits vorhanden, nur ausführen)
- Create/Modify: `README.md` (Installer-Abschnitt)

- [ ] **Step 1: Alle Unit-Tests ausführen**

Run: `bash tests/run.sh`
Expected: Alle `test_*.sh` PASS, Exit 0.

- [ ] **Step 2: Idempotenz-Check vorbereiten (manuell, optional, NICHT dry-run)**

Hinweis für den Ausführenden: Ein echter Lauf verändert das System. Falls in einer
Wegwerf-VM/Container getestet wird: `./install.sh --no-packages` zweimal laufen
lassen — der zweite Lauf darf keine Konflikte/Backups erzeugen, nur „bereits
verlinkt"-Meldungen. Auf dem produktiven System NICHT erforderlich.

- [ ] **Step 3: README-Abschnitt ergänzen**

Add to `README.md` (anlegen, falls nicht vorhanden):

```markdown
## Installation

Nach einer Neuinstallation:

```bash
git clone <dieses-repo> ~/git/dotfiles
cd ~/git/dotfiles
./install.sh            # Arch: Pakete + Symlinks + systemd + fisher
```

Optionen:
- `--dry-run` — zeigt nur, was passieren würde
- `--no-packages` — nur Symlinks/systemd/fisher
- `--distro <arch|debian|fedora>` — Erkennung übersteuern

Debian/Fedora werden best-effort unterstützt (Symlinks immer; Pakete soweit
verfügbar — der Hyprland/quickshell-Stack ist dort i.d.R. nicht paketiert).

Optionaler Schritt nach der Installation (Papirus-Ordnerfarbe):

```bash
papirus-folders -C cat-mocha-teal --theme Papirus-Dark
```
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document install.sh usage"
```

---

## Self-Review-Ergebnis

**Spec coverage:** Alle Spec-Abschnitte sind abgedeckt — Verzeichnisstruktur (Tasks 2–8), `install.sh`-Ablauf (Task 8), common.sh (Task 2), packages.sh (Tasks 3+7), symlinks.sh inkl. interaktivem Konflikt-Handling (Task 4), systemd.sh inkl. sunshine-Skip (Task 5), fisher.sh (Task 6), Paketlisten inkl. AUR/yay-Bootstrap (Tasks 3+7), Post-Install-Hinweise mit `cat-mocha-teal` + rodecaster-tidal-bridge (Task 8), `--dry-run`/`--no-packages`/`--distro` (Task 8), best-effort Debian/Fedora (Task 7), Testing-Strategie (Tasks 1–9).

**Placeholder scan:** Keine TBD/TODO; jeder Code-Step enthält vollständigen Code.

**Type/Name consistency:** Funktionsnamen konsistent über Tasks: `parse_package_list`, `detect_distro` (setzt `DETECTED_DISTRO`), `link_item`/`link_dotfiles`, `setup_systemd_services`, `setup_fisher`, `install_packages`. Globale `DRY_RUN`, `DOTFILES_DIR`, `CONFLICT_ALL`, `BACKUP_DIR` durchgängig verwendet. `run()`-Wrapper überall für Seiteneffekte genutzt.

**Nicht im Scope (bewusst):** Helfer-Skripte, rodecaster-tidal-bridge-Setup, garantiertes Debian/Fedora-Setup, Rollback.
