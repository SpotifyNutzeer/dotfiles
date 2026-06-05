# Dotfiles-Installer — Design

**Datum:** 2026-06-05
**Status:** Genehmigt, bereit für Implementierungsplan

## Ziel

Ein Script, das nach einer Neuinstallation die Dotfiles dieses Repos einrichtet:
Pakete installieren, Configs per Symlink verknüpfen, systemd-User-Services
aktivieren und fish-Plugins installieren. Primärziel ist **Arch Linux** (voll
unterstützt); Debian und Fedora sind **best-effort** (Symlinks + fisher immer,
Pakete soweit verfügbar).

## Entscheidungen (aus dem Brainstorming)

- **Verknüpfungsmethode:** Symlinks (keine Kopien, kein GNU stow).
- **Pakete:** Auf Arch werden Pakete installiert (pacman + AUR via `yay`), danach
  Symlinks. Auf Debian/Fedora best-effort.
- **Konflikt-Handling:** interaktiv pro Eintrag nachfragen, Default = Backup.
- **Zusätzlich zu `.config`:** `.vimrc` verlinken, systemd-User-Services
  verlinken + enablen, fisher-Plugins installieren.
- **Nicht im Scope:** Helfer-Skripte (`vfio/`, `davinci-fix.sh`,
  `launchsteamgame.sh`) werden nicht verlinkt.
- **Architektur:** modular (Option B) — Orchestrator + `lib/`-Module +
  `packages/`-Listen. Bewusst flach gehalten, kein Over-Engineering.

## Verzeichnisstruktur

```
install.sh              # Orchestrator: Args parsen, Distro erkennen, Module aufrufen
lib/
  common.sh             # Logging/Farben, confirm(), detect_distro(), Pfad-Variablen
  packages.sh           # Paketinstallation je Distro (pacman/AUR, apt, dnf)
  symlinks.sh           # Symlinks + interaktives Konflikt-Handling
  systemd.sh            # User-Services verlinken + enablen
  fisher.sh             # fisher + Plugins aus fish_plugins
packages/
  arch-pacman.txt       # offizielle Repo-Pakete (eine pro Zeile, # = Kommentar)
  arch-aur.txt          # AUR-Pakete
  debian.txt            # best-effort gemappte Namen
  fedora.txt            # best-effort gemappte Namen
docs/superpowers/specs/ # dieses Dokument
```

## Ablauf von `install.sh`

1. **Argumente parsen:**
   - `--no-packages` — nur Symlinks/systemd/fisher, keine Paketinstallation.
   - `--dry-run` — alle Aktionen nur anzeigen, nichts ausführen.
   - `--distro <arch|debian|fedora>` — automatische Erkennung übersteuern.
   - `-h|--help` — Usage.
2. **Distro erkennen** via `/etc/os-release` (`ID` / `ID_LIKE`).
3. **Pakete installieren** (`packages.sh`), außer bei `--no-packages`.
4. **Symlinks setzen** (`symlinks.sh`): `.config/*` + `.vimrc`.
5. **systemd-User-Services** (`systemd.sh`): verlinken + enablen.
6. **fisher-Plugins** (`fisher.sh`).
7. **Abschluss-Hinweise** ausgeben (u.a. `rodecaster-tidal-bridge`, optionaler
   Papirus-Folders-Farbschritt).

Bei `--dry-run` führt jedes Modul nur `log`-Ausgaben aus, keine
Seiteneffekte (keine Installation, keine Symlinks, kein enable).

## Module

### lib/common.sh
- Farbiges Logging: `log_info`, `log_warn`, `log_error`, `log_ok`.
- `confirm <prompt>` — ja/nein-Abfrage.
- `detect_distro` — gibt `arch` | `debian` | `fedora` | `unknown` zurück.
- Pfad-Variablen: `DOTFILES_DIR` (Repo-Wurzel, robust aus Script-Pfad
  abgeleitet), `CONFIG_SRC="$DOTFILES_DIR/.config"`, `CONFIG_DST="$HOME/.config"`.
- `DRY_RUN`-Flag respektieren (von `install.sh` exportiert).

### lib/packages.sh
- `install_packages <distro>`.
- **Arch:**
  - `pacman -S --needed` mit der Liste aus `packages/arch-pacman.txt`.
  - AUR-Helfer: prüfen ob `yay` vorhanden; falls nicht, bootstrappen
    (`git clone https://aur.archlinux.org/yay.git` in temp-Dir +
    `makepkg -si`). Setzt `base-devel` + `git` voraus (sind in der pacman-Liste).
  - `yay -S --needed` mit der Liste aus `packages/arch-aur.txt`.
- **Debian:** `sudo apt-get update` + `sudo apt-get install -y` mit
  `packages/debian.txt`; fehlende Pakete werden gewarnt, brechen nicht ab.
- **Fedora:** `sudo dnf install -y` mit `packages/fedora.txt`; analog
  best-effort.
- Kommentare (`#`) und Leerzeilen in den Listen werden ignoriert.

### lib/symlinks.sh
- Verlinkt **pro Top-Level-Eintrag** in `.config/` das ganze Verzeichnis/die
  Datei nach `~/.config/<name>`. **Ausnahme:** `systemd` (Sonderbehandlung in
  `systemd.sh`).
- Verlinkt zusätzlich `.vimrc` → `~/.vimrc`.
- **Idempotenz:** Zeigt das Ziel bereits korrekt auf die Repo-Quelle, wird der
  Eintrag stillschweigend übersprungen.
- **Konflikt-Handling (interaktiv):** Existiert am Ziel etwas anderes (Datei,
  Verzeichnis oder falscher Symlink), fragt das Script pro Eintrag:
  `[B]ackup (Default) / [s]kip / [o]verwrite / [A]lle backuppen`.
  - **Backup:** Ziel nach `~/.dotfiles-backup-<YYYYMMDD-HHMMSS>/` verschieben,
    dann Symlink setzen.
  - **skip:** Eintrag unverändert lassen, Warnung ausgeben.
  - **overwrite:** Ziel löschen, dann Symlink setzen.
  - **Alle backuppen:** Wahl für alle folgenden Konflikte merken.

**Bekannte Konsequenz:** Da ganze Verzeichnisse verlinkt werden, landen
Dateien, die Programme zur Laufzeit in z.B. `~/.config/fish/` schreiben
(fisher-Updates, generierte Completions), direkt im Repo. Das ist für dieses
Setup gewollt (`fish_plugins` ist eingecheckt).

### lib/systemd.sh
- Behandelt `~/.config/systemd/user` **separat** statt es als Ganzes zu
  verlinken — sonst könnte `systemctl --user enable` seine `.wants`-Symlinks
  nicht sauber anlegen.
- Verlinkt nur die einzelnen `*.service`-Dateien aus
  `.config/systemd/user/*.service` nach `~/.config/systemd/user/`.
- Die im Repo eingecheckten `*.target.wants/`-Verzeichnisse werden **ignoriert**;
  die Aktivierung übernimmt `systemctl --user enable`.
- Aktiviert: `fosi-keepalive.service`, `hyprpolkitagent.service`.
- **`sunshine.service` wird übersprungen** (sunshine wird nicht mehr installiert).
- `systemctl --user daemon-reload` nach dem Verlinken.

### lib/fisher.sh
- Setzt voraus, dass `fish` installiert und `~/.config/fish` verlinkt ist.
- Installiert fisher, falls nicht vorhanden (offizielle Bootstrap-Methode via
  `curl`).
- Installiert/aktualisiert die Plugins aus `~/.config/fish/fish_plugins`
  (`jorgebucaran/fisher`, `catppuccin/fish`) via `fisher update`.

## Paketlisten

### packages/arch-pacman.txt
```
fish kitty alacritty tmux starship htop vim
hyprland hyprpolkitagent
pipewire pipewire-pulse wireplumber
sox
rofi-wayland cava mangohud
brightnessctl playerctl
ttf-jetbrains-mono-nerd papirus-icon-theme
git curl base-devel
```
(Jeweils eine pro Zeile in der echten Datei.)

### packages/arch-aur.txt
```
quickshell
papirus-folders-catppuccin-git
```

### packages/debian.txt / packages/fedora.txt
Best-effort gemappte Namen. Pakete wie `hyprland`, `quickshell`,
`papirus-folders-catppuccin-git` sind dort i.d.R. **nicht** verfügbar und werden
beim Lauf als Warnung gemeldet (kein Abbruch). Diese Listen enthalten die
gemappten Namen der verfügbaren Pakete (Shell, Terminals, pipewire, fonts etc.)
mit Kommentaren bei den nicht verfügbaren.

## Post-Install-Hinweise (am Ende des Laufs)

1. **Papirus-Folders-Farbe (optional):** Das AUR-Paket installiert das Theme,
   färbt aber nichts automatisch. Hinweis ausgeben bzw. optional ausführen:
   `papirus-folders -C cat-mocha-blue --theme Papirus-Dark`
   (Akzentfarbe `cat-mocha-blue` als Default; im Script leicht änderbar.)
2. **rodecaster-tidal-bridge:** eigenes Projekt, nicht Teil dieses Installers.
   Hinweis: manuell von https://github.com/SpotifyNutzeer/rodecaster-tidal-bridge
   klonen und einrichten (liegt lokal unter `~/git/rodecaster-tidal-bridge`).
   Die `config.toml` wird über die normale `.config`-Verlinkung mitgenommen.

## Fehlerbehandlung

- `set -euo pipefail` im Orchestrator; Module sind Funktionen, die bei harten
  Fehlern (z.B. fehlende `pacman` auf Arch) abbrechen.
- Best-effort-Schritte (Debian/Fedora-Pakete, fisher) brechen **nicht** den
  ganzen Lauf ab, sondern warnen und machen weiter.
- Fehlt ein AUR-Helfer und das Bootstrapping schlägt fehl, werden AUR-Pakete
  übersprungen (Warnung), der Rest läuft weiter.
- `--dry-run` führt keinerlei Seiteneffekte aus.

## Testing

- **Manuell/Smoke:** `--dry-run` auf dem aktuellen System — Ausgabe muss alle
  geplanten Symlinks, Pakete und Service-Aktivierungen zeigen, ohne etwas zu
  ändern.
- **Idempotenz:** Zweiter Lauf nach erfolgreichem ersten Lauf darf keine
  Konflikte erzeugen und keine Backups anlegen.
- **Konflikt:** Künstlich eine Datei am Ziel anlegen und das interaktive
  Backup/skip/overwrite-Verhalten prüfen.
- Wo sinnvoll, reine Funktionen (z.B. Listen-Parsing in `packages.sh`) mit
  bats oder einfachen Shell-Assertions testen.

## Nicht im Scope (YAGNI)

- Verlinken der Helfer-Skripte (`vfio/`, `davinci-fix.sh`, `launchsteamgame.sh`).
- Installation/Setup von `rodecaster-tidal-bridge` selbst.
- Garantiert funktionierendes Debian/Fedora-Setup (nur best-effort).
- Deinstallations-/Rollback-Routine (Backups erlauben manuelles Zurückspielen).
