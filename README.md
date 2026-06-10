# dotfiles

Persönliche Konfiguration für ein Arch-Linux/Hyprland-Setup (Catppuccin Mocha).

## Installation

Nach einer Neuinstallation:

```bash
git clone https://github.com/SpotifyNutzeer/dotfiles ~/git/dotfiles
cd ~/git/dotfiles
./install.sh            # Arch: Pakete + Symlinks + systemd + fisher
```

Der Installer:

0. aktiviert sudo-Passwort-Feedback (Sternchen beim Tippen) über ein
   validiertes Drop-in unter `/etc/sudoers.d/` und setzt die Login-Shell auf
   fish (`chsh`, idempotent; distro-unabhängig),
1. passt auf Arch `/etc/pacman.conf` an (`Color`, `ParallelDownloads`,
   `multilib`; mit Backup), synchronisiert die Paket-DBs und installiert die
   Pakete aus `packages/` (`pacman` + AUR via `yay`, das bei Bedarf
   gebootstrappt wird). Die App-Pakete (discord, brave-beta-bin,
   tidal-hifi-tidaluna, vencord-hook) stehen in den `arch-*`-Listen; der
   Gaming-Stack (steam, gamemode, gamescope, wine, proton-ge, …) ebenso. Der
   NVIDIA-Stack aus `packages/arch-nvidia.txt` (inkl. `lib32-nvidia-utils`)
   wird nur installiert, wenn `lspci` eine NVIDIA-GPU meldet. Sofern
   kein anderer Display-Manager vorhanden ist, wird SDDM installiert, mit dem
   Catppuccin-Theme (aus `system/sddm.conf.d/`) konfiguriert und aktiviert,
1. (b) richtet auf Arch das Gaming-/Performance-Tuning aus `system/` ein:
   zram (`zram-generator.conf` + sysctl-Swap-Tuning, sofort aktiv), udev-Regel
   für CPU-Power-Anzeige in MangoHud, NVIDIA-modprobe-Optionen (KMS,
   `PreserveVideoMemoryAllocations`) und — auf X3D-CPUs — die automatische
   CCD-Umschaltung: gamemode schaltet beim Spielstart aufs Cache-CCD und
   danach zurück (`/usr/local/bin/x3d-mode` + visudo-validiertes
   sudoers-Drop-in, Hooks in `.config/gamemode.ini`),
1. (c) trägt ksshaskpass als grafischen sudo-Askpass-Helper in
   `/etc/sudo.conf` ein (`sudo -A` funktioniert dann auch ohne Terminal),
2. verlinkt `.config/*` und `.vimrc` ins Home sowie die Wallpaper aus
   `wallpapers/` nach `~/Pictures/Wallpapers/` (bei Konflikten wird interaktiv
   gefragt: Backup / skip / overwrite),
3. verlinkt die eigenen systemd-User-Units und aktiviert die in den
   `*.target.wants/` deklarierten Services (`sunshine` ausgenommen),
4. installiert die fish-Plugins aus `fish_plugins` via fisher,
5. installiert vim-plug und die in der `.vimrc` deklarierten vim-Plugins.

### Optionen

- `--dry-run` — zeigt nur, was passieren würde, ohne etwas zu verändern
- `--no-packages` — nur Symlinks/systemd/fisher, keine Paketinstallation
- `--distro <arch|debian|fedora>` — automatische Erkennung übersteuern

### Debian / Fedora

Best-effort: Symlinks und fisher laufen überall; Pakete werden soweit verfügbar
installiert (fehlende werden nur gewarnt). Der Hyprland/quickshell-Stack ist auf
Debian/Fedora i.d.R. nicht paketiert — erwarte dort kein vollständiges Setup.

### Nach der Installation (optional)

Papirus-Ordnerfarbe auf das Catppuccin-Mocha-Akzent setzen:

```bash
papirus-folders -C cat-mocha-teal --theme Papirus-Dark
```

`rodecaster-tidal-bridge` ist ein eigenes Projekt und nicht Teil des Installers:
<https://github.com/SpotifyNutzeer/rodecaster-tidal-bridge> (manuell einrichten;
die `config.toml` wird über die `.config`-Verlinkung mitgenommen).

## Tests

```bash
bash tests/run.sh
```

Abhängigkeitsfreies Bash-Harness; testet die reinen Funktionen (Distro-Erkennung,
Listen-Parsing, Symlink-/Konflikt-Logik, systemd-Aktivierungsableitung). Die
eigentliche Paketinstallation wird über `./install.sh --dry-run` verifiziert.
