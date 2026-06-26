# NixOS-Install Runbook (RTX-4090-Desktop, Dual-Boot neben Arch)

> **Ziel:** NixOS auf den frei werdenden Windows-Platz von `nvme1n1`, eigener
> systemd-boot, Arch bleibt unangetastet als Fallback. OS-Wahl per
> Firmware-Bootmenü.
>
> **Repo:** `https://github.com/<dein-user>/<nixos-repo>` ← hier eintragen!

---

## ⚠️ Disk-Layout (auswendig kennen, bevor du partitionierst)

| Device | Größe | Inhalt | Aktion |
|---|---|---|---|
| `nvme0n1` | 932 G | **Arch komplett** (ESP + root) | **NICHTS anfassen** |
| `nvme1n1p1` | **2,6 T btrfs** | **Arch `/home`** | **🚫 NIEMALS anfassen** |
| `nvme1n1p2` | 16 M | MS Reserved | löschen |
| `nvme1n1p3` | ~1 T ntfs | Windows C: | löschen |
| `nvme1n1p4` | 785 M | Win Recovery | löschen |

**Nur `nvme1n1` p2/p3/p4 löschen. Die 2,6-T-Partition (`p1`) ist dein Home.**

---

## 0. Letzter Backup-Check
SSH-/GPG-Keys und alles Lokal-only gesichert? Der Plan fasst `/home` nicht an —
aber es liegt auf derselben Disk wie die zu löschenden Partitionen.

## 1. Stick booten & root werden
USB im **Firmware-Bootmenü** wählen (UEFI). Terminal auf:
```bash
sudo -i
ping -c2 nixos.org      # Internet da?
```
> Falls die Live-GUI mit dem 4090/nouveau zickt: **Strg+Alt+F3** → TTY, gleiche Schritte.

## 2. ⚠️ Disks identifizieren
```bash
lsblk
```
Gegen die Tabelle oben prüfen. `nvme0n1` = Arch → in Ruhe lassen.
`nvme1n1p1` (2,6 T) = `/home` → **NIEMALS**.

## 3. Partitionieren (visuell, damit du `/home` siehst)
```bash
cfdisk /dev/nvme1n1
```
- **Lösche** nur `p2`, `p3`, `p4` (16M / ~1T / 785M — **nicht** die 2,6T!).
- Im freien Platz neu anlegen:
  - **1 GB** → Typ **„EFI System"**
  - **Rest** → Typ **„Linux filesystem"**
- **Write** → `yes` → **Quit**.
- `lsblk` → neue Namen merken (z. B. ESP = `nvme1n1p2`, root = `nvme1n1p3`).

## 4. Formatieren (Namen aus Schritt 3!)
```bash
mkfs.fat -F32 -n NIXBOOT /dev/nvme1n1p2     # neue 1G-ESP
mkfs.ext4  -L nixos      /dev/nvme1n1p3     # neue root
```

## 5. Mounten
```bash
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/NIXBOOT /mnt/boot
```

## 6. Echte Hardware-Config generieren
```bash
nixos-generate-config --root /mnt
grep stateVersion /mnt/etc/nixos/configuration.nix   # diesen Wert merken!
```

## 7. Flake-Repo reinholen & finalisieren
```bash
git clone https://github.com/<dein-user>/<nixos-repo> /mnt/etc/nixos-config
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos-config/hosts/desktop/
cd /mnt/etc/nixos-config
```
Edits (mit `vim`/`nano`):
- **`flake.nix`**: `desktop`-Zeile einkommentieren → `desktop = mkHost "desktop";`
- **`hosts/desktop/default.nix`**: `system.stateVersion` auf den Wert aus Schritt 6.
- Platzhalter-`hardware-configuration.nix` ist jetzt durch die echte ersetzt ✓.

**⚠️ Flake-Falle — auch im Installer:** alles tracken, sonst sieht der Flake die Dateien nicht:
```bash
git add -A
```

## 8. Installieren
```bash
nixos-install --flake /mnt/etc/nixos-config#desktop
```
Lädt das ganze System (NVIDIA-Treiber, Hyprland …) — braucht Netz + Zeit.
Am Ende: **root-Passwort** setzen.

## 9. ⚠️ paul-Passwort (sonst Aussperrung)
`paul` ist in der Config ohne Passwort (kein Passwort im öffentlichen Repo!).
Noch im Installer:
```bash
nixos-enter --root /mnt
passwd paul
exit
```

## 10. Reboot
```bash
reboot
```
Stick ziehen → **Firmware-Bootmenü** → NixOS-Eintrag (bzw. `nvme1n1`) wählen.
Erster Boot → **TTY-Login** (noch kein Greeter, gewollt). Als `paul` einloggen.

---

## Wenn etwas schiefgeht
- **`nixos-install` bricht mit Eval-Fehler ab** → fast immer vergessenes `git add`
  (Schritt 7) oder Tippfehler im `desktop`-Host. Fehlermeldung notieren.
- **Alter Repo-Stand geklont** → letzte Edits vor dem Booten gepusht?
- **Black Screen beim ersten Boot** → im systemd-boot-Menü die vorige Generation
  wählen; notfalls Kernel-Param `nomodeset`. Arch-Fallback bleibt jederzeit übers
  Firmware-Menü erreichbar.

## Danach (nicht mehr im Installer)
1. Bootet das Basissystem & Login klappt → **melden**, dann gemeinsam:
   Hyprland vom TTY testen (`Hyprland`), dann greetd / NVIDIA-Wayland / HDR —
   eine Variable nach der anderen.
2. Repo sauber einrichten: `git clone … ~/git/nixos`, die neue
   `hosts/desktop/hardware-configuration.nix` committen & pushen.
3. `stateVersion` ist gesetzt → **nie wieder ändern**.
