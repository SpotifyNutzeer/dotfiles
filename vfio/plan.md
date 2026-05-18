# Windows-11-Gaming-VM mit Single-GPU-Passthrough — Implementation-Plan

> **Für ausführende Agenten:** Benutze `superpowers:executing-plans` oder
> `superpowers:subagent-driven-development`, um diesen Plan Task-für-Task
> abzuarbeiten. Schritte verwenden Checkbox-Syntax (`- [ ]`).

**Ziel:** RTX 4090 wird dynamisch zwischen Linux-Host und Windows-11-VM
gewechselt; FH6 läuft in der VM auf nativer GPU-Performance.

**Architektur:** QEMU/KVM + libvirt mit Pre/Post-Hooks, die Display-Manager
und Nvidia-Treiber beim VM-Start abräumen und beim VM-Stop wiederherstellen.

**Tech-Stack:** Arch Linux + zen-Kernel, QEMU/KVM, libvirt, OVMF, swtpm,
virtio, vfio-pci.

**Referenz-Spec:** `/home/paul/git/dotfiles/vfio/design.md`

> **Hinweis zu TDD bei System-Config:** Bei System-Setup gibt es keinen
> Code-Test-Loop ("write failing test → implement → pass"). Stattdessen folgt
> jeder Konfigurations-Schritt dem Muster
> **(1) Befehl ausführen → (2) Output gegen erwartetes Ergebnis prüfen →
> (3) erst dann commit/weiter**. Verifikations-Schritte sind explizit.

---

## Phase 0: Configs ins dotfiles-Repo einchecken

Source of Truth für alle Config-Dateien (Hook-Skripte, VM-XML) wird
`/home/paul/git/dotfiles/vfio/` im bestehenden dotfiles-Repo. Deployment
in `/etc/libvirt/...` passiert per `sudo cp`. So bleibt alles versioniert
und reversibel.

`design.md`, `plan.md` und `usb-port-finder.sh` liegen bereits im
Verzeichnis. Hook-Skripte und VM-XML kommen in späteren Phasen dazu.

### Task 0.1: Design und Plan in dotfiles-Repo committen

**Files:**
- Existing repo: `/home/paul/git/dotfiles/`
- Already in place: `vfio/design.md`, `vfio/plan.md`, `vfio/usb-port-finder.sh`

- [ ] **Step 1: .gitignore für VM-Artefakte ergänzen**

VM-Disk-Images und ISOs liegen unter `/home/paul/vms/` bzw.
`/home/paul/iso/` — also außerhalb des Repos. Trotzdem als Safety-Net im
dotfiles-`.gitignore` ausschließen:

```bash
cd /home/paul/git/dotfiles
grep -q '^vfio/\*.qcow2' .gitignore 2>/dev/null || cat >> .gitignore <<'EOF'
vfio/*.qcow2
vfio/*.iso
vfio/*.fd
EOF
```

- [ ] **Step 2: Neue Dateien committen**

```bash
cd /home/paul/git/dotfiles
git add vfio/ .gitignore
git status
```

Expected: drei neue Dateien in `vfio/`, evtl. geänderte `.gitignore`.

```bash
git commit -m "Add VFIO single-GPU passthrough design and plan"
```

Expected: ein neuer Commit mit ~3-4 Dateien.

Expected: ein neuer Commit mit drei Dateien.

---

## Phase 1: Host-Vorbereitung

### Task 1.1: Pakete installieren

- [ ] **Step 1: Pakete installieren**

```bash
sudo pacman -S --needed \
  qemu-full libvirt edk2-ovmf swtpm \
  dnsmasq iptables-nft \
  virt-manager openssh
```

Expected: alle Pakete vorhanden oder neu installiert, keine Fehler.

- [ ] **Step 2: OVMF-Pfade verifizieren**

```bash
ls /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd /usr/share/edk2/x64/OVMF_VARS.4m.fd
```

Expected: beide Dateien existieren. Falls die Pfade abweichen
(z.B. `OVMF_CODE.secboot.fd` ohne `4m`-Suffix), die `<loader>`- und
`<nvram>`-Pfade in den XML-Dateien (Tasks 5.1, 7.1) entsprechend anpassen.

### Task 1.2: libvirtd aktivieren

- [ ] **Step 1: libvirtd-Socket aktivieren**

```bash
sudo systemctl enable --now libvirtd.socket
```

- [ ] **Step 2: Default-Netz starten**

```bash
sudo virsh net-autostart default
sudo virsh net-start default 2>&1 | tee /tmp/net-start.log
```

Expected: `Network default started` ODER `Network is already active`.

- [ ] **Step 3: User in libvirt + kvm Gruppe**

```bash
sudo usermod -aG libvirt,kvm paul
```

- [ ] **Step 4: Neu-Login der Shell-Session**

Anweisung: aus aktueller Hyprland-Session ausloggen und wieder einloggen,
oder `newgrp libvirt` in neuer Shell. Verifikation:

```bash
groups | grep -oE 'libvirt|kvm'
```

Expected: `libvirt` und `kvm` werden aufgelistet.

---

## Phase 2: BIOS + Boot-Cmdline

### Task 2.1: BIOS-Check (manuell)

- [ ] **Step 1: BIOS-Einstellungen prüfen**

Anweisung: Neustart, ins UEFI-Setup. Folgendes sicherstellen:

- **SVM Mode**: Enabled
- **IOMMU**: Enabled (oder Auto)
- **Above 4G Decoding**: Enabled
- **Resizable BAR**: Enabled (optional, aber empfohlen)

Speichern und booten.

- [ ] **Step 2: IOMMU im laufenden System verifizieren**

```bash
ls /sys/kernel/iommu_groups/ | wc -l
```

Expected: Zahl > 30 (du hattest 35 Gruppen — wenn 0 oder leer: IOMMU
nicht aktiv, BIOS nochmal prüfen).

### Task 2.2: Kernel-Cmdline um Hugepages-Reservation ergänzen

**Files:**
- Modify: `/boot/loader/entries/<deine-zen-entry>.conf`

- [ ] **Step 1: Aktuellen Boot-Eintrag finden**

```bash
sudo bootctl status | head -40
```

Expected: zeigt `default:` mit Eintrags-Dateinamen. Notiere den Pfad.

- [ ] **Step 2: Aktuelle Cmdline sichern**

```bash
cd /home/paul/git/dotfiles/vfio
sudo cp /boot/loader/entries/<deine-entry>.conf systemd-boot-entry.conf.bak
git add systemd-boot-entry.conf.bak
git commit -m "Backup original systemd-boot entry"
```

- [ ] **Step 3: Cmdline editieren**

```bash
sudo $EDITOR /boot/loader/entries/<deine-entry>.conf
```

An die `options …`-Zeile (am Ende) anhängen:

```
default_hugepagesz=1G hugepagesz=1G hugepages=32
```

- [ ] **Step 4: Änderung verifizieren**

```bash
grep '^options' /boot/loader/entries/<deine-entry>.conf
```

Expected: Zeile enthält `default_hugepagesz=1G hugepagesz=1G hugepages=32`.

### Task 2.3: Reboot + Hugepages verifizieren

- [ ] **Step 1: Reboot**

```bash
sudo reboot
```

- [ ] **Step 2: Nach Reboot — Hugepages prüfen**

```bash
grep -i huge /proc/meminfo
```

Expected:
- `HugePages_Total: 32`
- `Hugepagesize: 1048576 kB`

Falls `HugePages_Total: 0`: Cmdline wurde nicht angewandt — `cat /proc/cmdline`
prüfen, Tippfehler suchen.

- [ ] **Step 3: RAM-Bilanz prüfen**

```bash
free -h
```

Expected: `total` etwa 32 GiB weniger als vorher (96 → ~64 GiB nutzbar),
weil Hugepages dauerhaft reserviert sind.

---

## Phase 3: VM-Storage + ISOs

### Task 3.1: VMs-Verzeichnis vorbereiten

- [ ] **Step 1: Verzeichnis erstellen + btrfs-CoW deaktivieren**

```bash
mkdir -p /home/paul/vms
chattr +C /home/paul/vms
```

- [ ] **Step 2: chattr verifizieren**

```bash
lsattr -d /home/paul/vms
```

Expected: das `C`-Flag erscheint im Output (z.B. `---------------C------ /home/paul/vms`).

- [ ] **Step 3: 500-GiB-qcow2 erstellen**

```bash
qemu-img create -f qcow2 /home/paul/vms/win.qcow2 500G
```

Expected: `Formatting '/home/paul/vms/win.qcow2', fmt=qcow2 size=536870912000 …`

- [ ] **Step 4: Größe und CoW-Status der erstellten Datei prüfen**

```bash
ls -lh /home/paul/vms/win.qcow2
lsattr /home/paul/vms/win.qcow2
```

Expected: Datei ist klein (~196 KiB, thin-provisioned). `C`-Flag ist gesetzt.

### Task 3.2: ISOs besorgen

**Files:**
- Create (Download): `/home/paul/iso/Win11.iso`
- Create (Download): `/home/paul/iso/virtio-win.iso`

- [ ] **Step 1: ISO-Verzeichnis anlegen**

```bash
mkdir -p /home/paul/iso
```

- [ ] **Step 2: Windows-11-ISO herunterladen**

Anweisung: Im Browser auf
https://www.microsoft.com/software-download/windows11 das offizielle
Multi-Edition-ISO holen. Datei nach `/home/paul/iso/Win11.iso` legen.

- [ ] **Step 3: virtio-win.iso herunterladen**

```bash
curl -L -o /home/paul/iso/virtio-win.iso \
  https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

Expected: Download ohne Fehler, ca. 700 MB.

- [ ] **Step 4: Beide ISOs verifizieren (vorhanden, lesbar)**

```bash
ls -lh /home/paul/iso/
file /home/paul/iso/Win11.iso /home/paul/iso/virtio-win.iso
```

Expected: beide als "ISO 9660 CD-ROM filesystem data" erkannt.

---

## Phase 4: Notfall-Zugang (SSH von zweitem Gerät)

Wenn die GPU im VM-Setup hängt, brauchst du Zugang zum Host **von außen**,
weil dein eigenes Display und deine Tastatur weg sind.

### Task 4.1: SSH-Server einrichten

- [ ] **Step 1: sshd aktivieren**

```bash
sudo systemctl enable --now sshd
```

- [ ] **Step 2: Status verifizieren**

```bash
systemctl is-active sshd
ss -ltnp | grep ':22 '
```

Expected: `active`, und Port 22 lauscht.

- [ ] **Step 3: lokale IP herausfinden**

```bash
ip -4 addr show | grep 'inet ' | grep -v 127.0.0.1
```

Expected: deine LAN-IP. Notieren — die brauchst du gleich.

### Task 4.2: SSH-Login vom zweiten Gerät testen

- [ ] **Step 1: Vom Handy/Laptop testen**

Anweisung: Auf dem zweiten Gerät (Handy mit Termux/JuiceSSH, Laptop mit
OpenSSH), folgenden Befehl ausführen:

```bash
ssh paul@<deine-lokale-IP>
```

Expected: Login erfolgreich. **Nicht weitermachen, wenn das nicht klappt** —
ohne funktionierenden Notfall-Zugang darfst du keinen Single-GPU-VM-Start
versuchen.

- [ ] **Step 2: Cheatsheet auf zweitem Gerät bereit**

In einer Notiz-App auf dem zweiten Gerät folgendes ablegen:

```
ssh paul@<lokale-IP>
sudo virsh destroy win
sudo /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh
sudo systemctl start sddm
sudo reboot
```

---

## Phase 5: Bootstrap-VM (Windows installieren)

### Task 5.1: Bootstrap-XML schreiben

**Files:**
- Create: `/home/paul/git/dotfiles/vfio/win-bootstrap.xml`

- [ ] **Step 1: Bootstrap-XML schreiben**

Inhalt: identisch zur Produktiv-XML aus `design.md` Kapitel 6, **aber:**

- Alle `<hostdev>`-Blöcke (GPU, GPU-Audio, USB-Controller) **entfernt**.
- Stattdessen `<graphics>` und `<video>` für VNC eingefügt:

```xml
<graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'/>
<video>
  <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
</video>
```

- Zwei CDROM-Devices ergänzt:

```xml
<disk type='file' device='cdrom'>
  <driver name='qemu' type='raw'/>
  <source file='/home/paul/iso/Win11.iso'/>
  <target dev='sda' bus='sata'/>
  <readonly/>
  <boot order='2'/>
</disk>
<disk type='file' device='cdrom'>
  <driver name='qemu' type='raw'/>
  <source file='/home/paul/iso/virtio-win.iso'/>
  <target dev='sdb' bus='sata'/>
  <readonly/>
</disk>
```

Komplette Datei (basierend auf design.md Kapitel 6, mit den oben genannten
Anpassungen) in `/home/paul/git/dotfiles/vfio/win-bootstrap.xml` schreiben.

- [ ] **Step 2: XML validieren**

```bash
virt-xml-validate /home/paul/git/dotfiles/vfio/win-bootstrap.xml
```

Expected: `… validates`. Falls Fehler: Tippfehler in XML suchen.

- [ ] **Step 3: Committen**

```bash
cd /home/paul/git/dotfiles/vfio
git add win-bootstrap.xml
git commit -m "Add bootstrap VM XML (VNC + ISOs, no passthrough)"
```

### Task 5.2: Bootstrap-VM definieren und starten

- [ ] **Step 1: VM bei libvirt registrieren**

```bash
sudo virsh define /home/paul/git/dotfiles/vfio/win-bootstrap.xml
```

Expected: `Domain 'win' defined from /home/paul/git/dotfiles/vfio/win-bootstrap.xml`.

- [ ] **Step 2: VM starten**

```bash
sudo virsh start win
```

Expected: `Domain 'win' started`. Falls Fehler "cannot allocate memory":
Hugepages prüfen (`grep Huge /proc/meminfo`).

- [ ] **Step 3: VNC-Display öffnen**

```bash
virt-viewer --connect qemu:///system win &
```

Expected: VNC-Fenster mit OVMF-Bootscreen, kurz danach Windows-Setup.

### Task 5.3: Windows 11 installieren

- [ ] **Step 1: Windows-Setup durchlaufen**

Anweisung im VNC-Fenster:

1. Sprache/Layout wählen.
2. "Jetzt installieren".
3. Edition wählen (z.B. Pro).
4. Lizenzbedingungen akzeptieren.
5. "Benutzerdefiniert: Nur Windows installieren".

- [ ] **Step 2: virtio-Storage-Treiber laden**

Bei "Wohin möchten Sie Windows installieren?": **Keine Disks sichtbar.**

1. "Treiber laden" klicken.
2. Im virtio-win-CDROM (typischerweise Laufwerk `E:` oder `D:`) navigieren zu:
   `viostor\w11\amd64\`
3. Treiber bestätigen.
4. Disk erscheint, auswählen, "Weiter".

- [ ] **Step 3: Installation laufen lassen**

Windows kopiert Dateien, Reboot. VM bootet automatisch von der Disk weiter.

- [ ] **Step 4: OOBE — lokales Konto erzwingen**

Bei "Sign in to your Microsoft account":

1. `Shift+F10` → öffnet cmd.
2. Tippen: `start ms-cxh:localonly` und Enter.
3. Lokalen Benutzer anlegen ohne Microsoft-Account-Zwang.

- [ ] **Step 5: Bis zum Desktop kommen**

Anweisung: alle Datenschutz-Toggles auf "Nein", Sprach-Setup minimal halten,
bis Windows-Desktop erscheint.

### Task 5.4: virtio-Treiber-Suite installieren

- [ ] **Step 1: virtio-win-CD in Windows öffnen**

In Windows-Explorer: virtio-win-CDROM (Laufwerk `E:` o.ä.) öffnen,
`virtio-win-gt-x64.msi` doppelklicken.

- [ ] **Step 2: Installer durchlaufen lassen**

Alle Defaults bestätigen. Installiert Netzwerk-, Balloon-, Serial-Treiber.

- [ ] **Step 3: Reboot in Windows**

Anweisung: Windows neu starten (`shutdown /r /t 0` in cmd oder
über Startmenü).

- [ ] **Step 4: Netzwerk in Windows prüfen**

Nach Reboot: in Windows ein Browser-Fenster öffnen, eine beliebige URL
laden. Internet sollte funktionieren (libvirt-NAT).

- [ ] **Step 5: Windows sauber herunterfahren**

In Windows: Start → Power → Herunterfahren. Auf Host:

```bash
sudo virsh list --all
```

Expected: VM `win` mit Zustand `shut off`.

---

## Phase 6: Hook-Skripte deployen

### Task 6.1: Hook-Skripte im Repo schreiben

**Files:**
- Create: `/home/paul/git/dotfiles/vfio/hooks/qemu`
- Create: `/home/paul/git/dotfiles/vfio/hooks/qemu.d/win/prepare/begin/start.sh`
- Create: `/home/paul/git/dotfiles/vfio/hooks/qemu.d/win/release/end/revert.sh`

- [ ] **Step 1: Dispatcher schreiben**

Inhalt: exakt aus `design.md` Kapitel 7.1 übernehmen, in
`/home/paul/git/dotfiles/vfio/hooks/qemu` ablegen.

- [ ] **Step 2: Pre-Start-Hook schreiben**

Inhalt: exakt aus `design.md` Kapitel 7.2 übernehmen, in
`/home/paul/git/dotfiles/vfio/hooks/qemu.d/win/prepare/begin/start.sh` ablegen.

- [ ] **Step 3: Post-Stop-Hook schreiben**

Inhalt: exakt aus `design.md` Kapitel 7.3 übernehmen, in
`/home/paul/git/dotfiles/vfio/hooks/qemu.d/win/release/end/revert.sh` ablegen.

- [ ] **Step 4: Ausführbar markieren + committen**

```bash
cd /home/paul/git/dotfiles/vfio
chmod +x hooks/qemu hooks/qemu.d/win/prepare/begin/start.sh hooks/qemu.d/win/release/end/revert.sh
git add hooks/
git commit -m "Add libvirt hook scripts for single-GPU passthrough"
```

### Task 6.2: Skripte nach /etc/libvirt deployen

- [ ] **Step 1: Verzeichnisstruktur anlegen**

```bash
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win/prepare/begin
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win/release/end
```

- [ ] **Step 2: Skripte kopieren**

```bash
sudo cp /home/paul/git/dotfiles/vfio/hooks/qemu /etc/libvirt/hooks/qemu
sudo cp /home/paul/git/dotfiles/vfio/hooks/qemu.d/win/prepare/begin/start.sh \
        /etc/libvirt/hooks/qemu.d/win/prepare/begin/start.sh
sudo cp /home/paul/git/dotfiles/vfio/hooks/qemu.d/win/release/end/revert.sh \
        /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh
```

- [ ] **Step 3: Ausführbarkeit setzen**

```bash
sudo chmod +x /etc/libvirt/hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu.d/win/prepare/begin/start.sh
sudo chmod +x /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh
```

- [ ] **Step 4: Verifizieren**

```bash
ls -la /etc/libvirt/hooks/qemu
ls -la /etc/libvirt/hooks/qemu.d/win/prepare/begin/start.sh
ls -la /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh
```

Expected: alle drei Dateien existieren, alle haben `x`-Flag.

- [ ] **Step 5: libvirtd neu laden (damit Hooks erkannt werden)**

```bash
sudo systemctl restart libvirtd
```

### Task 6.3: Revert-Skript isoliert smoke-testen

Bevor wir den ersten Produktiv-Start wagen, testen wir, ob das
**Revert-Skript** sauber durchläuft. Es lädt nur Module — das ist
nicht-destruktiv, solange Nvidia-Module schon geladen sind.

- [ ] **Step 1: Aktuellen Treiber-Status notieren**

```bash
lsmod | grep -E 'nvidia|vfio' > /tmp/before.txt
cat /tmp/before.txt
```

- [ ] **Step 2: Revert-Skript ausführen**

```bash
sudo /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh
```

Expected: Skript läuft durch ohne Abbruch. Output sollte `[hook] sddm starten…`
als letzte Zeile haben (sddm war evtl. eh schon aktiv — kein Schaden).

- [ ] **Step 3: Treiber-Status danach prüfen**

```bash
lsmod | grep -E 'nvidia|vfio'
```

Expected: `nvidia`-Module geladen, `vfio_pci` nicht geladen.

---

## Phase 7: Produktiv-XML (mit Passthrough)

### Task 7.1: Produktiv-XML schreiben

**Files:**
- Create: `/home/paul/git/dotfiles/vfio/win.xml`

- [ ] **Step 1: Komplette Produktiv-XML schreiben**

Inhalt: **exakt** aus `design.md` Kapitel 6 übernehmen — die komplette
130-zeilige XML mit allen `<hostdev>`-Blöcken, ohne `<graphics>`/`<video>`,
ohne CDROMs. Datei: `/home/paul/git/dotfiles/vfio/win.xml`.

- [ ] **Step 2: XML validieren**

```bash
virt-xml-validate /home/paul/git/dotfiles/vfio/win.xml
```

Expected: `… validates`.

- [ ] **Step 3: Committen**

```bash
cd /home/paul/git/dotfiles/vfio
git add win.xml
git commit -m "Add production VM XML with GPU and USB passthrough"
```

### Task 7.2: Bootstrap-XML durch Produktiv-XML ersetzen

- [ ] **Step 1: Aktuelle Definition prüfen**

```bash
sudo virsh list --all
```

Expected: VM `win` im Zustand `shut off`.

- [ ] **Step 2: Neue Definition einspielen**

```bash
sudo virsh define /home/paul/git/dotfiles/vfio/win.xml
```

Expected: `Domain 'win' defined from /home/paul/git/dotfiles/vfio/win.xml`.
**Wichtig**: alte NVRAM-Datei (`/var/lib/libvirt/qemu/nvram/win_VARS.fd`)
bleibt bestehen — Windows-Boot-Einträge bleiben erhalten.

- [ ] **Step 3: Definition verifizieren**

```bash
sudo virsh dumpxml win | grep -E 'hostdev|graphics|video' | head -20
```

Expected: mehrere `<hostdev>`-Zeilen, **keine** `<graphics>` oder `<video>`.

---

## Phase 8: Erster Produktiv-Start

**Vor diesem Schritt zwingend:**

- Zweites Gerät mit SSH-Verbindung zum Host bereit (Task 4.2).
- Alle GPU-nutzenden Apps schließen (Browser mit Hardware-Beschleunigung,
  Spiele, alles was nvidia-smi anzeigt).
- Verifikation:

```bash
sudo lsof /dev/nvidia* 2>/dev/null
```

Wenn diese Liste leer ist: gefahrlos weiter. Wenn nicht: Apps schließen.

### Task 8.1: VM zum ersten Mal mit Passthrough starten

- [ ] **Step 1: VM starten**

```bash
sudo virsh start win
```

Erwartetes Verhalten:

1. Display wird schwarz (sddm gestoppt, GPU wird übernommen).
2. ~30 Sekunden nichts.
3. Bild zurück: OVMF-Bootscreen, dann Windows-Bootlogo, dann Desktop.

Falls nach 60 Sekunden noch schwarz: **vom zweiten Gerät SSH-Login**, dann:

```bash
sudo virsh destroy win
sudo /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh
sudo systemctl start sddm
```

und Logs prüfen:

```bash
sudo journalctl -u libvirtd -n 100
sudo cat /var/log/libvirt/qemu/win.log | tail -50
```

### Task 8.2: Nvidia-Treiber in Windows installieren

- [ ] **Step 1: Browser in Windows öffnen**

Nvidia-Treiber von https://www.nvidia.com/Download/index.aspx holen
(GeForce 4090, Windows 11, Game Ready Driver).

- [ ] **Step 2: Installer ausführen**

Standard-Installation, Express-Optionen.

- [ ] **Step 3: Reboot in Windows**

- [ ] **Step 4: Treiber-Erkennung verifizieren**

In Windows: Geräte-Manager → Anzeigeadapter. Expected: "NVIDIA GeForce RTX
4090" ohne Warnzeichen.

- [ ] **Step 5: GPU-Auslastung testen**

In Windows: `nvidia-smi` in PowerShell, oder GPU-Z, oder einfach Task-
Manager → Leistung → GPU. Expected: ~24 GB VRAM verfügbar, niedriger Idle-
Verbrauch.

### Task 8.3: VM sauber herunterfahren und Revert verifizieren

- [ ] **Step 1: Windows herunterfahren**

Start → Power → Herunterfahren.

Erwartetes Verhalten:

1. Display wird schwarz.
2. ~30 Sekunden.
3. SDDM-Login-Screen erscheint.

- [ ] **Step 2: Host-Treiber-Status prüfen**

In SDDM einloggen, in Terminal:

```bash
lsmod | grep -E 'nvidia|vfio'
nvidia-smi
```

Expected: Nvidia-Module geladen, `nvidia-smi` listet die 4090 mit Treiber-
Version und 0% Auslastung.

- [ ] **Step 3: VM-Status prüfen**

```bash
sudo virsh list --all
```

Expected: `win` als `shut off`.

---

## Phase 9: Forza Horizon 6 installieren

### Task 9.1: Steam installieren

- [ ] **Step 1: VM erneut starten**

```bash
sudo virsh start win
```

- [ ] **Step 2: Steam in Windows installieren**

https://store.steampowered.com/about/ → Steam-Installer holen, ausführen,
Login.

### Task 9.2: FH6 installieren und testen

- [ ] **Step 1: FH6 in Steam-Bibliothek auswählen, installieren**

Anweisung: ~120 GB Download abwarten.

- [ ] **Step 2: Spiel starten**

- [ ] **Step 3: Performance prüfen**

In FH6: Grafik-Settings auf hoch, FPS-Anzeige ein.
Expected: stabile FPS auf High/Ultra, 100+ FPS bei 1440p.

Wenn FPS unerwartet niedrig:

- `nvidia-smi` in PowerShell: GPU-Auslastung > 90% im Gameplay? Wenn nein,
  CPU-Bottleneck → CPU-Pinning prüfen (Task-Manager → Detailansicht).
- Frametimes zucken? → Hyper-V-Enlightenments und Hugepages nochmal
  verifizieren.

### Task 9.3: VM-Aktivierung erinnern

- [ ] **Step 1: Windows-Lizenz aktivieren**

In Windows: Einstellungen → System → Aktivierung. Lizenzschlüssel oder
Account-Verknüpfung eingeben.

---

## Phase 10: Notfall-Plan einmal scharf testen

Damit du im Ernstfall nicht improvisieren musst, **testen** wir den
Notfall-Plan jetzt unter Idealbedingungen.

### Task 10.1: Hartes Abschießen + Recovery

- [ ] **Step 1: VM starten**

```bash
sudo virsh start win
```

- [ ] **Step 2: Vom zweiten Gerät SSH-Login während VM läuft**

Auf zweitem Gerät:

```bash
ssh paul@<deine-lokale-IP>
```

Expected: Login klappt **während** VM aktiv ist. Sehr wichtig — beweist,
dass dein Notfall-Zugang im Ernstfall funktioniert.

- [ ] **Step 3: VM hart abschießen**

In der SSH-Session:

```bash
sudo virsh destroy win
```

Expected: VM-Bild verschwindet sofort vom Hauptmonitor, Linux-Display
sollte zurückkommen (Hook `release/end` läuft).

- [ ] **Step 4: Falls Display nicht zurückkommt — manueller Revert**

In SSH-Session:

```bash
sudo /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh
sudo systemctl restart sddm
```

Erwartete Recovery binnen ~10 Sekunden.

- [ ] **Step 5: Notiz: was hat funktioniert, was nicht**

Wenn alles glatt lief: Notfall-Plan ist validiert.
Wenn etwas nicht klappte: jetzt fixen, **nicht** im echten Notfall.

---

## Phase 11: Optionale Verbesserungen (später, bei Bedarf)

Diese Tasks sind **nicht** Teil des Initial-Setups. Aufnehmen, wenn
Frametimes zucken oder Komfort fehlt:

- **CPU-Governor auf `performance`**: `sudo cpupower frequency-set -g performance`.
- **systemd-CPU-Affinity** für System-Services auf CCD1: Kernel-Cmdline um
  `systemd.cpu_affinity=8-15,24-31` ergänzen, Reboot.
- **MSI-Interrupts** in Windows für GPU/USB explizit erzwingen (MSI-Util-Tool).
- **Looking-Glass-Migration**: Wenn der Single-GPU-Schmerz irgendwann doch
  nervt, ist der Wechsel zu Dual-GPU (iGPU als Host) klein — die VM-XML
  bleibt fast unverändert, nur die Hooks entfallen.

---

## Self-Review-Checkliste (für den Plan-Autor)

- [x] Jedes Spec-Kapitel von `design.md` hat mindestens einen umsetzenden Task.
- [x] Keine "TBD" / "TODO" / "implement later" / "appropriate error handling".
- [x] Jeder Befehl hat eine erwartete Ausgabe oder Verifikations-Schritt.
- [x] Notfall-Plan ist Phase 4 (vor erstem Produktiv-Start), nicht erst hinterher.
- [x] Hugepages, IOMMU, BIOS-Flags werden vor dem ersten VM-Start verifiziert.
- [x] Bootstrap-Phase mit VNC und Produktiv-Phase mit Passthrough sind klar getrennt.
