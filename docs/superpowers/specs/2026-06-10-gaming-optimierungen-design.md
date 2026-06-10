# Gaming-Optimierungen im Installer — Design

Datum: 2026-06-10 · Status: vom User bestätigt (X3D dynamisch via gamemode,
zram-Tuning anwenden + Installer, eigene Paketlisten mit NVIDIA-Erkennung,
lib32-nvidia-utils sofort installieren)

## Problem

Das System (Arch, Ryzen 9 9950X3D, RTX 4090, Hyprland) ist manuell für Gaming
optimiert, aber der Installer reproduziert davon nichts: Gaming-Pakete fehlen
in `packages/`, System-Configs (`/etc/modprobe.d/nvidia.conf`,
`/etc/udev/rules.d/51-rapl.rules`, `/etc/systemd/zram-generator.conf`) liegen
nur lokal. Zusätzlich gefunden: `lib32-nvidia-utils` fehlt (32-bit-Vulkan
defekt), zram läuft mit Disk-Swap-Sysctl-Defaults, und der X3D-Modus steht
permanent auf `frequency` (Spiele profitieren vom Cache-CCD).

## Design

### Pakete

- `packages/arch-pacman.txt`: neue Gaming-Sektion (steam, steam-devices,
  gamemode, lib32-gamemode, gamescope, wine, winetricks, vulkan-tools,
  zram-generator).
- `packages/arch-nvidia.txt` (neu): nvidia-open-dkms, nvidia-utils,
  lib32-nvidia-utils, opencl-nvidia, libva-nvidia-driver, linux-zen-headers.
  Wird nur installiert, wenn `lspci` eine NVIDIA-GPU meldet
  (`_nvidia_gpu_present`, via `$LSPCI` testbar).
- `packages/arch-aur.txt`: proton-ge-custom-bin, protonup-qt-bin,
  gamescope-session-git, gamescope-session-steam-git.

### System-Configs (neu: `lib/gaming.sh`, Quellen unter `system/`)

Nur auf Arch; jede Datei via `sudo install -Dm644`, idempotent, dry-run-fähig:

- `system/modprobe.d/nvidia.conf` → `/etc/modprobe.d/` (nur bei NVIDIA-GPU):
  `nvidia-drm modeset=1`, `NVreg_PreserveVideoMemoryAllocations=1`,
  `NVreg_DynamicPowerManagement=2`.
- `system/udev/51-rapl.rules` → `/etc/udev/rules.d/` (CPU-Power in MangoHud).
- `system/sysctl.d/99-zram.conf` → `/etc/sysctl.d/` + sofort anwenden:
  `vm.swappiness=180`, `vm.watermark_boost_factor=0`,
  `vm.watermark_scale_factor=125`, `vm.page-cluster=0` (Arch Wiki, zram).
- `system/zram-generator.conf` → `/etc/systemd/zram-generator.conf`,
  portabel als `zram-size = ram / 2`, zstd.

### X3D-Umschaltung via gamemode

- `system/bin/x3d-mode` → `/usr/local/bin/x3d-mode` (root, 0755): schreibt
  `cache|frequency` nach `/sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode`;
  Pfad via `$X3D_SYSFS` übersteuerbar (Tests).
- Sudoers-Drop-in `/etc/sudoers.d/x3d-mode` (visudo-validiert, Muster wie
  pwfeedback): `$USER` darf das Skript ohne Passwort ausführen — gamemoded
  läuft als User-Service.
- `.config/gamemode.ini` kommt ins Repo (wird mitverlinkt) und erhält
  `[custom] start/end`-Hooks: Spielstart → `cache`, Spielende → `frequency`.
- Setup nur, wenn der `amd_x3d_vcache`-Treiber existiert (kein X3D → skip).

### Integration

`install.sh` ruft nach den Paketen `setup_gaming "$DETECTED_DISTRO"` auf
(non-arch → Hinweis + skip). NVIDIA-Pakete laufen innerhalb von
`install_packages_arch` (respektiert `--no-packages`).

### Tests

`tests/test_gaming.sh`: x3d-mode-Skript gegen Fake-sysfs (tmpdir) —
gültiger/ungültiger Modus, fehlendes Gerät; NVIDIA-Erkennung mit gefaktem
`lspci`; Paketlisten-Parsing der neuen Listen.

## Verworfene Alternativen

- **X3D permanent auf `cache`** (udev-Regel): einfacher, kostet aber
  Desktop-/Build-Last Single-Core-Takt.
- **`--gaming`-Flag**: saubere Trennung, aber es ist das Haupt-Setup des
  Rechners — opt-in würde nur vergessen.
- **Nicht übernommen:** `mitigations=off` (Sicherheits-Trade-off, Nutzen heute
  minimal), gamemode-`renice` (bringt mit gamescope praktisch nichts).
