# NixOS Clean-Install Runbook — Desktop (Ryzen 9 9950X3D / RTX 4090)

> **Ziel:** Arch komplett platt machen, NixOS sauber neu installieren.
> Beide NVMe als **btrfs**.
> **Repo:** `git@github.com:SpotifyNutzeer/nixos.git` (Flake, Host `desktop`)

---

## ⚠️⚠️ DATENVERLUST — VORHER LESEN

Dieses Runbook **löscht BEIDE NVMe vollständig**, inklusive der **Arch-`/home`** auf der 4-TB-Platte. Es gibt danach **kein** Zurück.

**Bevor du irgendwas anfasst:**
- [ ] `~/git/nixos` committet **und gepusht** (`git push`) — sonst ist deine Config weg.
- [ ] `~/git/dotfiles` committet **und gepusht** (Flake-Input + dieses Runbook).
- [ ] Alles aus `~` gesichert, was du behalten willst (Dokumente, Wallpaper, Saves, `~/.ssh`, GPG-Keys…). Die 4-TB-`/home` wird gelöscht.
- [ ] CoolerControl-Config ist schon im Repo (`hosts/desktop/coolercontrol/`), wird per Seed wiederhergestellt.

---

## Disk-Layout (Ziel)

| Disk (by-id) | Größe | Partition | FS | Mount |
|---|---|---|---|---|
| `nvme-CT1000T700SSD3_2321E6DB0D4C` | 1 TB | `-part1` (1 GiB) | FAT32 | `/boot` (ESP) |
| | | `-part2` (Rest) | btrfs | `/`, `/nix`, `/var/log` |
| `nvme-CT4000P310SSD8_2518500EC39B` | 4 TB | `-part1` (ganz) | btrfs | `/home` |

**btrfs-Subvolumes:** 1 TB → `@` (/), `@nix` (/nix), `@log` (/var/log) · 4 TB → `@home` (/home)
**Kein Disk-Swap** — die Config nutzt zram (`gaming.nix`).

> **Warum by-id:** Die `/dev/nvme0n1` / `nvme1n1`-Namen **tauschen zwischen Boots**. `by-id` (Modell+Seriennummer) ist stabil. **Niemals** `nvmeXnY` zum Partitionieren benutzen.

---

## 0. NixOS-Installer booten

1. Aktuelles **NixOS Minimal ISO** auf USB (z. B. mit `dd` von einem anderen Rechner / Ventoy).
2. Im UEFI vom USB booten (Secure Boot **aus**).
3. Netzwerk:
   - **Ethernet:** geht meist automatisch.
   - **WLAN:** `iwctl` → `station wlan0 connect <SSID>`.
   - Prüfen: `ping -c2 nixos.org`
4. Root werden: `sudo -i`

---

## 1. Disks identifizieren & VERIFIZIEREN

```sh
DISK1=/dev/disk/by-id/nvme-CT1000T700SSD3_2321E6DB0D4C   # 1 TB  -> root+boot
DISK4=/dev/disk/by-id/nvme-CT4000P310SSD8_2518500EC39B   # 4 TB  -> home
```

**Gate — erst weiter, wenn das stimmt** (Größe & Modell müssen passen):

```sh
lsblk -do NAME,SIZE,MODEL,SERIAL "$(readlink -f $DISK1)" "$(readlink -f $DISK4)"
```
Erwartung: `DISK1` = ~932 G Crucial T700, `DISK4` = ~3,6 T Crucial P310.
Falls die by-id-Namen nicht existieren: `ls /dev/disk/by-id/ | grep nvme` und Variablen anpassen.

---

## 2. Disks komplett wipen

```sh
wipefs -a "$DISK1" "$DISK4"
sgdisk --zap-all "$DISK1"
sgdisk --zap-all "$DISK4"
```

---

## 3. Partitionieren

**1 TB — ESP (1 GiB) + btrfs-Root:**
```sh
sgdisk -n1:0:+1G -t1:ef00 -c1:ESP   "$DISK1"
sgdisk -n2:0:0   -t2:8300 -c2:nixos "$DISK1"
```

**4 TB — eine btrfs-Partition:**
```sh
sgdisk -n1:0:0 -t1:8300 -c1:home "$DISK4"
```

```sh
partprobe; udevadm settle
```

---

## 4. Formatieren

```sh
mkfs.fat -F32 -n ESP "${DISK1}-part1"
mkfs.btrfs -f -L nixos "${DISK1}-part2"
mkfs.btrfs -f -L home  "${DISK4}-part1"
```

---

## 5. Subvolumes anlegen

```sh
# Root-Disk
mount "${DISK1}-part2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
umount /mnt

# Home-Disk
mount "${DISK4}-part1" /mnt
btrfs subvolume create /mnt/@home
umount /mnt
```

---

## 6. Mounten (mit Kompression + noatime)

```sh
OPTS=compress=zstd,noatime

mount -o subvol=@,$OPTS "${DISK1}-part2" /mnt
mkdir -p /mnt/{boot,nix,var/log,home}
mount -o subvol=@nix,$OPTS "${DISK1}-part2" /mnt/nix
mount -o subvol=@log,$OPTS "${DISK1}-part2" /mnt/var/log
mount -o subvol=@home,$OPTS "${DISK4}-part1" /mnt/home
mount "${DISK1}-part1" /mnt/boot
```

Prüfen:
```sh
findmnt -R /mnt
```
Erwartung: `/` `/nix` `/var/log` auf der 1-TB-btrfs (verschiedene subvol), `/home` auf der 4-TB-btrfs, `/boot` vfat.

---

## 7. hardware-configuration.nix generieren

Erzeugt die korrekten **neuen UUIDs/Subvol-Optionen** für genau dieses Layout:

```sh
nixos-generate-config --root /mnt
```
→ schreibt `/mnt/etc/nixos/hardware-configuration.nix`.

---

## 8. Flake holen & hardware-config übernehmen

> **WICHTIG:** Sowohl `nixos` als auch `dotfiles` müssen **public** auf GitHub sein (der Install klont das nixos-Repo per https und der Flake zieht `github:SpotifyNutzeer/dotfiles`). Private Repos → Installer scheitert ohne Token. Falls privat: vorher auf public stellen, oder Repo per USB nach `/mnt/root/nixos` kopieren.

```sh
# Falls git im Installer fehlt: in eine git-Shell wechseln und ALLE folgenden
# Befehle dieses Schritts darin ausführen:
#   nix-shell -p git

git clone https://github.com/SpotifyNutzeer/nixos.git /mnt/root/nixos

# frisch generierte hardware-config ins Repo kopieren (neue UUIDs!)
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/root/nixos/hosts/desktop/hardware-configuration.nix
```

> Der `git tree is dirty`-Hinweis beim Install ist **erwartet & ok** — Nix nimmt bei lokalem Flake den Arbeitsstand (inkl. der geänderten hardware-config).

---

## 9. Installieren

```sh
nixos-install --flake /mnt/root/nixos#desktop
```
- Lädt/baut viel (TidaLuna, Catppuccin, GE-Proton…) → **kann 20–40 min dauern**.
- Am Ende: **Root-Passwort** setzen, wenn gefragt.

**User-Passwort für `paul`:**
```sh
nixos-enter --root /mnt -c 'passwd paul'
```

---

## 10. Reboot

```sh
umount -R /mnt
reboot
```
USB ziehen. Im SDDM-Login die Session **„Hyprland (uwsm-managed)"** wählen (ist Default), als `paul` einloggen.

---

## 11. Erster Boot — Post-Install

Vieles passiert **automatisch** über die Config:
- gnome-keyring wird beim Login angelegt/entsperrt.
- **Tidal:** beim **ersten** Start einmalig Plugin-Permissions akzeptieren → ab dann gespeichert.
- **CoolerControl:** `config.toml`/`config-ui.json` werden per `systemd.tmpfiles` geseedet → Lüfterkurven da. Prüfen:
  ```sh
  for h in /sys/class/hwmon/hwmon*; do cat $h/name; done   # it87952 + it8696 müssen auftauchen
  systemctl status coolercontrold
  ```
- **240 Hz / Monitore:** beim ersten Login greift die HDMI-A-1-240-Hz-Cold-Start-Logik (exec-once) automatisch.

**Repo & SSH wieder einrichten** (für künftige `git push`):
```sh
# SSH-Key wiederherstellen (aus Backup) oder neu erzeugen + bei GitHub hinterlegen
mkdir -p ~/git && cd ~/git
git clone git@github.com:SpotifyNutzeer/nixos.git     # dein Arbeits-Repo
```
Die geänderte `hardware-configuration.nix` (neue UUIDs) committen & pushen, damit sie dauerhaft im Repo ist:
```sh
cd ~/git/nixos
git add hosts/desktop/hardware-configuration.nix
git commit -m "hardware-config: neues btrfs-Layout (1TB root, 4TB home)"
git push
```

---

## Anhang — Troubleshooting

- **it87 lädt nicht / nur ein Chip** → `sudo dmesg | grep -i it87`. Bei „no device"/falscher ID: `force_id` in `hosts/desktop/coolercontrol.nix` setzen (Block ist auskommentiert vorbereitet).
- **CoolerControl-Kurven fehlen** (Daemon hat Default angelegt) →
  ```sh
  sudo systemctl stop coolercontrold
  sudo rm /etc/coolercontrol/config.toml /etc/coolercontrol/config-ui.json
  sudo systemd-tmpfiles --create && sudo systemctl start coolercontrold
  ```
- **Geräte-UIDs weichen ab** → Profile importieren trotzdem; Lüfter des betroffenen Geräts im GUI einmal neu zuweisen.
- **Falsche Platte erwischt?** Wenn `lsblk` in Schritt 1 nicht 932 G / 3,6 T + die richtigen Modelle zeigt: **STOP**, by-id-Namen neu prüfen.

## Anhang — später automatisierbar

Dieses manuelle Partitionieren lässt sich mit **disko** deklarativ machen (`disko-install --flake … --disk main $DISK1 …`), dann ist auch das Disk-Layout reproducible. Für jetzt reicht dieses Runbook.
