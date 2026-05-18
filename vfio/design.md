# VFIO Single-GPU-Passthrough für Windows-11-Gaming-VM

**Datum:** 2026-05-18
**Ziel:** Windows-11-VM auf Arch Linux mit dedizierter Nutzung der RTX 4090 (Single-GPU-Passthrough), primär für Forza Horizon 6.
**Status:** Design final, Implementierung steht aus.

---

## 1. Zielbild und Trade-offs

Im VM-Betrieb wird der gesamte Linux-Desktop heruntergefahren, die RTX 4090 dynamisch vom Nvidia-Treiber gelöst und an die VM gebunden. Die VM nutzt die Karte dann nativ. Beim Herunterfahren der VM kehrt die GPU zum Host zurück und der Login-Screen erscheint wieder.

**Bewusst akzeptierte Einschränkungen:**

- Host-Desktop, Browser, Discord etc. sind während VM-Laufzeit nicht verfügbar.
- Kein Looking-Glass möglich (setzt Dual-GPU voraus).
- Bluetooth bleibt am Host (Group 21, Frontpanel), in der VM also nicht verfügbar.
- Wechsel kostet ca. 30 Sekunden schwarzen Bildschirm pro Richtung.

**Bewusst nicht verfolgte Alternativen:**

- iGPU des 9950X3D als Host-GPU (vom Benutzer abgelehnt — Komfort hätte stark erhöht: kein Bind/Unbind, Looking-Glass möglich, Host bleibt während VM-Betrieb verfügbar).
- Dual-GPU mit zusätzlicher diskreter Karte.
- vGPU/SR-IOV (Hardware unterstützt es nicht).

---

## 2. Hardware-Inventar

| Komponente | Modell | Hinweis |
|---|---|---|
| CPU | AMD Ryzen 9 9950X3D | 16C/32T, 2 CCDs (CCD0 = V-Cache, CCD1 = Standard) |
| RAM | 96 GiB | 32 GiB werden als 1G-Hugepages reserviert |
| GPU | Nvidia RTX 4090 (AD102, `10de:2684`) | Kein Reset-Bug, kein KVM-Hide nötig |
| Mainboard | AM5 (B650/X670/X870, modellabhängig) | IOMMU sauber, Group 13 enthält nur GPU+GPU-Audio |
| System-SSD | Crucial T700 1 TB (NVMe) | `/` als btrfs |
| Daten-SSD | Crucial P310 4 TB (NVMe) | `/home` als btrfs, beheimatet VM-Image |
| Host-OS | Arch Linux, Kernel `linux-zen` 7.0.9 | Wayland + Hyprland + SDDM |

### 2.1 IOMMU-Layout (relevante Gruppen)

| Group | PCI | Device | Verwendung |
|---|---|---|---|
| 13 | `01:00.0` + `01:00.1` | RTX 4090 + GPU-HDMI-Audio | **→ VM** |
| 21 | `11:00.0` (Bus 1+2) | Chipset USB 3.x (Frontpanel) | Bleibt Host (Yubikey, Bluetooth) |
| 22 | `13:00.0` (Bus 3+4) | Chipset USB 3.x (hintere I/O, Hauptmenge) | **→ VM** |
| 27 | `77:00.0` (Bus 5+6) | ASMedia USB 3.2 (USB-2-Ports hinten) | **→ VM** |
| 32 | `79:00.4` (Bus 9+10) | AMD Raphael USB 3.1 (USB-C) | **→ VM** |

---

## 3. Boot-Konfiguration

### 3.1 Kernel-Cmdline-Ergänzung

Bootloader ist systemd-boot. Die Cmdline lebt im Boot-Entry unter `/boot/loader/entries/<entry>.conf` als `options …`-Zeile.

**Hinzufügen** (ans Ende anhängen):

```
default_hugepagesz=1G hugepagesz=1G hugepages=32
```

Wirkt: 32 × 1 GiB als Hugepages werden direkt beim Boot reserviert (32 GiB), bleiben permanent gebunden, garantiert verfügbar für die VM.

**NICHT** hinzufügen (gerne in Tutorials genannt, hier nicht nötig):

- `amd_iommu=on` / `iommu=pt` — auf modernem AMD per Default aktiv.
- `vfio-pci.ids=…` — würde die GPU zur Bootzeit binden und Host hätte keine GPU mehr. Wir binden dynamisch im Hook.
- `isolcpus=…` — starre Isolierung, verbraucht CCD0 dauerhaft. Nicht nötig, libvirt-Pinning reicht.

### 3.2 BIOS-Voraussetzungen

Im UEFI sicherstellen:

- **SVM** (AMD-V) aktiv.
- **IOMMU** aktiv (oft als "SVM Mode" + "IOMMU = Enabled/Auto", je nach Vendor).
- **Above 4G Decoding** aktiv (für die 4090 ohnehin Pflicht).
- **Resizable BAR** aktiv (optional, kein Showstopper).

### 3.3 Hugepages verifizieren (nach Reboot)

```bash
grep -i huge /proc/meminfo
# Erwartet: HugePages_Total: 32, Hugepagesize: 1048576 kB
```

---

## 4. Pakete

```bash
sudo pacman -S --needed \
  qemu-full libvirt edk2-ovmf swtpm \
  dnsmasq iptables-nft \
  virt-manager
```

- `qemu-full` enthält QEMU + alle Architekturen + virtio + Tools.
- `libvirt` ist der Daemon (`libvirtd`).
- `edk2-ovmf` liefert OVMF-UEFI-Firmware (inkl. Secure-Boot-Variante).
- `swtpm` für TPM-2.0-Emulation (Win11 Pflicht).
- `dnsmasq` + `iptables-nft` für libvirts default-NAT-Netz.
- `virt-manager` nur als Notfall-GUI; produktiv wird `virsh` aus der TTY genutzt.

**Dienste:**

```bash
sudo systemctl enable --now libvirtd.socket
sudo virsh net-autostart default
sudo virsh net-start default
```

User in passende Gruppen:

```bash
sudo usermod -aG libvirt,kvm paul
```

(Neu-Login danach.)

---

## 5. VM-Storage vorbereiten

```bash
mkdir -p /home/paul/vms
# btrfs CoW deaktivieren, bevor das Image erstellt wird (qcow2 macht selbst CoW)
chattr +C /home/paul/vms
qemu-img create -f qcow2 /home/paul/vms/win.qcow2 500G
```

Vererbung von `+C` wirkt nur für danach erstellte Dateien — daher Reihenfolge wichtig.

ISOs ablegen:

```bash
mkdir -p /home/paul/iso
# Win11_24H2_*.iso (offiziell von Microsoft)
# virtio-win.iso (https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md)
```

---

## 6. libvirt-VM-Definition (XML)

Datei: `/etc/libvirt/qemu/win.xml` (via `virsh define win.xml`).

Es gibt **zwei Varianten**: eine **Bootstrap-Variante** für die Erst-Installation (mit VNC, ohne GPU/USB-PT) und eine **Produktiv-Variante** (mit GPU/USB-PT, ohne VNC). Unten die Produktiv-Variante. Die Bootstrap-Variante ist im Abschnitt "Installations-Workflow" beschrieben.

```xml
<domain type='kvm'>
  <name>win</name>
  <memory unit='KiB'>33554432</memory>
  <currentMemory unit='KiB'>33554432</currentMemory>
  <memoryBacking>
    <hugepages>
      <page size='1' unit='GiB'/>
    </hugepages>
    <nosharepages/>
  </memoryBacking>

  <vcpu placement='static'>16</vcpu>
  <iothreads>1</iothreads>
  <cputune>
    <!-- CCD0 (V-Cache): Cores 0-7, SMT-Siblings 16-23 -->
    <vcpupin vcpu='0'  cpuset='0'/>
    <vcpupin vcpu='1'  cpuset='16'/>
    <vcpupin vcpu='2'  cpuset='1'/>
    <vcpupin vcpu='3'  cpuset='17'/>
    <vcpupin vcpu='4'  cpuset='2'/>
    <vcpupin vcpu='5'  cpuset='18'/>
    <vcpupin vcpu='6'  cpuset='3'/>
    <vcpupin vcpu='7'  cpuset='19'/>
    <vcpupin vcpu='8'  cpuset='4'/>
    <vcpupin vcpu='9'  cpuset='20'/>
    <vcpupin vcpu='10' cpuset='5'/>
    <vcpupin vcpu='11' cpuset='21'/>
    <vcpupin vcpu='12' cpuset='6'/>
    <vcpupin vcpu='13' cpuset='22'/>
    <vcpupin vcpu='14' cpuset='7'/>
    <vcpupin vcpu='15' cpuset='23'/>
    <!-- QEMU- und IOThread-Threads auf CCD1 (außerhalb des V-Cache-CCDs) -->
    <emulatorpin cpuset='8-9'/>
    <iothreadpin iothread='1' cpuset='10-11'/>
  </cputune>

  <!--
    Hinweis: libvirts firmware='efi' Autoselection scheitert auf Arch, weil
    keine pre-enrolled OVMF_VARS-Variante existiert. Wir geben Loader und
    NVRAM-Template daher explizit an und ueberlassen das Key-Enrollment
    der Windows-Installation.
  -->
  <os>
    <type arch='x86_64' machine='pc-q35-9.0'>hvm</type>
    <loader readonly='yes' secure='yes' type='pflash'>/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd</loader>
    <nvram template='/usr/share/edk2/x64/OVMF_VARS.4m.fd'>/var/lib/libvirt/qemu/nvram/win_VARS.fd</nvram>
    <boot dev='hd'/>
  </os>

  <features>
    <acpi/>
    <apic/>
    <hyperv mode='custom'>
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
      <vpindex state='on'/>
      <synic state='on'/>
      <stimer state='on'/>
      <reset state='on'/>
      <vendor_id state='on' value='1234567890ab'/>
      <frequencies state='on'/>
      <reenlightenment state='on'/>
      <tlbflush state='on'/>
      <ipi state='on'/>
    </hyperv>
    <vmport state='off'/>
    <smm state='on'/>
  </features>

  <cpu mode='host-passthrough' check='none' migratable='off'>
    <topology sockets='1' dies='1' cores='8' threads='2'/>
    <cache mode='passthrough'/>
    <feature policy='require' name='topoext'/>
    <feature policy='require' name='invtsc'/>
  </cpu>

  <clock offset='localtime'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
    <timer name='kvmclock' present='yes'/>
    <timer name='tsc' present='yes' mode='native'/>
    <timer name='hypervclock' present='yes'/>
  </clock>

  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>

  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>

    <!-- Boot-Disk -->
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap' iothread='1' queues='4'/>
      <source file='/home/paul/vms/win.qcow2'/>
      <target dev='vda' bus='virtio'/>
      <boot order='1'/>
    </disk>

    <!-- Netzwerk -->
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>

    <!-- TPM 2.0 emuliert -->
    <tpm model='tpm-crb'>
      <backend type='emulator' version='2.0'/>
    </tpm>

    <!-- Serial (für Debug, falls VM nicht bootet) -->
    <serial type='pty'><target type='isa-serial' port='0'/></serial>
    <console type='pty'><target type='serial' port='0'/></console>

    <!-- KEIN <graphics>, KEIN <video> -->
    <!-- Output kommt physisch aus der 4090. Wenn doch noch ein Fallback-VNC nötig:
         <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'/>
         <video><model type='qxl'/></video>
         …aber im Produktiv-Betrieb weglassen.
    -->

    <!-- GPU + GPU-Audio (Group 13) -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x05' slot='0x00' function='0x0' multifunction='on'/>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x05' slot='0x00' function='0x1'/>
    </hostdev>

    <!-- USB-Controller Group 22 (Bus 3+4, hintere I/O) -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x13' slot='0x00' function='0x0'/>
      </source>
    </hostdev>

    <!-- USB-Controller Group 27 (Bus 5+6, ASMedia USB 3.2) -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x77' slot='0x00' function='0x0'/>
      </source>
    </hostdev>

    <!-- USB-Controller Group 32 (Bus 9+10, USB-C) -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x79' slot='0x00' function='0x4'/>
      </source>
    </hostdev>
  </devices>
</domain>
```

**Hinweise zur XML:**

- `managed='yes'` bedeutet, libvirt erledigt das Bind-an-vfio-pci selbst. Wir machen es im Hook trotzdem manuell, weil bei Single-GPU der Kontext (Display-Manager, Module) eine bestimmte Reihenfolge braucht, die libvirts Automatik nicht abdeckt.
- `<vendor_id value='1234567890ab'/>` ist kosmetisch — ältere Nvidia-Treiber hatten KVM-Detection. Ada-Karten haben das Problem nicht mehr, schadet aber nicht.
- `<feature name='invtsc'/>` ist wichtig für stabile Frametimes auf modernen AMD.
- `cache='none' io='native'` ist der Standard für maximale Disk-Performance.

---

## 7. Hook-Skripte (Single-GPU-Tanz)

Verzeichnisstruktur (libvirt-Standard):

```
/etc/libvirt/hooks/
├── qemu                       (Dispatcher, ruft passendes Sub-Skript auf)
└── qemu.d/
    └── win/
        ├── prepare/begin/start.sh
        └── release/end/revert.sh
```

### 7.1 Dispatcher: `/etc/libvirt/hooks/qemu`

```bash
#!/usr/bin/env bash
# Dispatcher: ruft passendes Sub-Skript aus qemu.d/<vm>/<action>/<subaction>/ auf

set -e

GUEST_NAME="$1"
HOOK_NAME="$2"
STATE_NAME="$3"

HOOKPATH="/etc/libvirt/hooks/qemu.d/${GUEST_NAME}/${HOOK_NAME}/${STATE_NAME}"

if [[ -f "$HOOKPATH" ]]; then
    exec "$HOOKPATH"
elif [[ -d "$HOOKPATH" ]]; then
    while read -r file; do
        [[ -x "$file" ]] && "$file"
    done < <(find -L "$HOOKPATH" -maxdepth 1 -type f -print)
fi
```

Ausführbar machen: `chmod +x /etc/libvirt/hooks/qemu`.

### 7.2 Pre-Start: `/etc/libvirt/hooks/qemu.d/win/prepare/begin/start.sh`

```bash
#!/usr/bin/env bash
# Pre-Start-Hook: Host-Desktop runterfahren, GPU + USB-Controller an vfio-pci binden.
# Wird von libvirt vor dem QEMU-Start ausgefuehrt. Bei Fehler: Revert + Abbruch
# (sonst sitzt der User im schwarzen TTY mit kaputtem Treiber-Zustand).

set -e

# Devices, die an vfio-pci wandern
GPU_PCI="0000:01:00.0"          # RTX 4090
GPU_AUDIO_PCI="0000:01:00.1"    # GPU-HDMI-Audio
USB_GROUP22="0000:13:00.0"
USB_GROUP27="0000:77:00.0"
USB_GROUP32="0000:79:00.4"

ALL_DEVICES=(
    "$GPU_PCI" "$GPU_AUDIO_PCI"
    "$USB_GROUP22" "$USB_GROUP27" "$USB_GROUP32"
)

# Bei Fehler: Revert ausloesen
trap '/etc/libvirt/hooks/qemu.d/win/release/end/revert.sh; exit 1' ERR

echo "[hook] sddm stoppen…"
systemctl stop sddm

# Warten bis Display-Manager wirklich weg
for i in {1..10}; do
    systemctl is-active sddm >/dev/null 2>&1 || break
    sleep 0.5
done

echo "[hook] auf TTY2 wechseln…"
chvt 2 || true

echo "[hook] EFI-Framebuffer entbinden…"
if [[ -d /sys/bus/platform/drivers/efi-framebuffer ]]; then
    echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true
fi
if [[ -d /sys/bus/platform/drivers/simple-framebuffer ]]; then
    for fb in /sys/bus/platform/drivers/simple-framebuffer/*; do
        [[ -L "$fb" ]] && echo "$(basename $fb)" > /sys/bus/platform/drivers/simple-framebuffer/unbind 2>/dev/null || true
    done
fi

echo "[hook] Nvidia-Module entladen…"
modprobe -r nvidia_uvm
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia

echo "[hook] vfio-Module laden…"
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci

echo "[hook] Devices an vfio-pci binden…"
for dev in "${ALL_DEVICES[@]}"; do
    vendor=$(cat /sys/bus/pci/devices/$dev/vendor)
    device=$(cat /sys/bus/pci/devices/$dev/device)
    # Aktuellen Treiber entbinden
    if [[ -L /sys/bus/pci/devices/$dev/driver ]]; then
        echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
    fi
    # vfio-pci als neuen Treiber registrieren und binden
    echo "${vendor#0x} ${device#0x}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
    echo "$dev" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
done

echo "[hook] Pre-Start fertig, libvirt kann QEMU starten."
```

### 7.3 Post-Stop: `/etc/libvirt/hooks/qemu.d/win/release/end/revert.sh`

```bash
#!/usr/bin/env bash
# Post-Stop-Hook: Devices zurueck an Host-Treiber, Display-Manager wieder hoch.
# Wird auch vom Pre-Start als Cleanup aufgerufen, falls dort etwas schiefgeht.

set +e   # Bei Revert: jeder Schritt soll versucht werden, auch wenn andere fehlschlagen

GPU_PCI="0000:01:00.0"
GPU_AUDIO_PCI="0000:01:00.1"
USB_GROUP22="0000:13:00.0"
USB_GROUP27="0000:77:00.0"
USB_GROUP32="0000:79:00.4"

ALL_DEVICES=(
    "$GPU_PCI" "$GPU_AUDIO_PCI"
    "$USB_GROUP22" "$USB_GROUP27" "$USB_GROUP32"
)

echo "[hook] Devices von vfio-pci entbinden…"
for dev in "${ALL_DEVICES[@]}"; do
    if [[ -L /sys/bus/pci/devices/$dev/driver ]]; then
        echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
    fi
done

echo "[hook] vfio-Module entladen…"
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

echo "[hook] Nvidia-Module laden…"
modprobe nvidia
modprobe nvidia_modeset
modprobe nvidia_drm modeset=1
modprobe nvidia_uvm

# Devices brauchen nicht explizit gebunden zu werden - Nvidia-Modul
# erkennt sie und bindet sie selbststaendig

echo "[hook] EFI-Framebuffer wird vom Nvidia-Treiber bzw. Display-Manager neu eingerichtet…"

echo "[hook] sddm starten…"
systemctl start sddm
```

Ausführbar machen:

```bash
chmod +x /etc/libvirt/hooks/qemu.d/win/prepare/begin/start.sh
chmod +x /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh
```

---

## 8. Installations-Workflow

### 8.1 Bootstrap-Phase (Windows installieren, ohne GPU-PT)

Vor dem ersten Start die **Produktiv-XML aus Abschnitt 6 modifizieren**, sodass:

- **Alle `<hostdev>`-Blöcke auskommentiert** sind (kein GPU, kein USB-PT).
- Ein `<graphics>` + `<video>`-Block hinzugefügt ist:

```xml
<graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
  <listen type='address' address='127.0.0.1'/>
</graphics>
<video>
  <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
</video>
```

- Zwei CDROM-Devices für die ISOs:

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

- Der `<boot order='1'/>` auf der `vda` bleibt, aber die `<os>`-Boot-Reihenfolge enthält zusätzlich CDROM.

**Ablauf:**

1. `virsh define win-bootstrap.xml`
2. `virsh start win`
3. `virt-viewer --connect qemu:///system win` (oder VNC-Client gegen `127.0.0.1:5900`).
4. Windows installieren. Bei Disk-Auswahl: "Treiber laden" → virtio-win-CDROM → `viostor` für die Windows-Version laden.
5. Bei OOBE lokales Konto erzwingen: `Shift+F10` öffnet `cmd`, dann `start ms-cxh:localonly` (oder `oobe\BypassNRO.cmd`).
6. Nach Boot: virtio-win-CDROM öffnen, `virtio-win-gt-x64.msi` ausführen → installiert alle restlichen virtio-Treiber.
7. Windows herunterfahren.

### 8.2 Übergang zur Produktiv-Phase

1. VM-XML auf die Produktiv-Variante aus Abschnitt 6 umstellen (`virsh edit win`):
   - `<graphics>` und `<video>` raus.
   - CDROM-Einträge raus (oder als "leer" beibehalten, damit später leicht ISOs einlegbar).
   - GPU- und USB-`<hostdev>`-Blöcke rein.
2. Hooks aus Abschnitt 7 deployen.
3. Sicherstellen, dass kein Programm gerade die 4090 nutzt (kein Browser mit Hardware-Beschleunigung etc. — am sichersten frisch nach Reboot).
4. `virsh start win`.
5. Nach ~30 Sekunden schwarzem Bildschirm: Windows bootet, Display kommt physisch aus der 4090.
6. In Windows: Nvidia-Treiber installieren (entweder Windows Update oder manueller Download).
7. Steam → FH6 installieren → testen.

### 8.3 Normalbetrieb

- **Start**: `virsh start win` aus einem Terminal (oder per Hotkey).
- **Stop**: in Windows herunterfahren, **nicht** mit `virsh destroy` (hartes Aus).
- **Notfall**: wenn Hook hängt oder VM nicht bootet → SSH von zweitem Gerät, `virsh destroy win`, `/etc/libvirt/hooks/qemu.d/win/release/end/revert.sh` manuell.

---

## 9. Bekannte Stolperfallen & Notfall-Plan

| Symptom | Ursache | Lösung |
|---|---|---|
| Pre-Start hängt beim `modprobe -r nvidia` | Ein Prozess hält den Treiber (z.B. Browser mit Cuda) | Vor VM-Start alle GPU-nutzenden Apps schließen; ggf. `lsof /dev/nvidia*` |
| Schwarzer Bildschirm bleibt nach VM-Stop | Nvidia-Treiber rebindet nicht sauber | TTY-Login via Notebook/Phone-SSH, `sudo systemctl restart sddm`; im Wiederholungsfall: Hook-Revert ergänzen um expliziten `nvidia-smi` |
| Windows bootet, aber kein Bild | EFI-Framebuffer noch gebunden / GPU-Reset im Schwebezustand | Erst Host-Reboot, dann erneut probieren. Bei wiederholtem Auftreten: ROM-Datei (vBIOS-Dump) in `<hostdev>` einbinden. |
| FH6 startet nicht, Online-Login schlägt fehl | Anti-Cheat erkennt KVM | (Risiko bekannt) `<hyperv><vendor_id state='on' value='1234567890ab'/>` ist gesetzt. Wenn das nicht reicht: nichts zu machen. |
| `virsh start win` schlägt mit "cannot allocate memory" fehl | Hugepages nicht ausreichend | `grep Huge /proc/meminfo`; Cmdline prüfen; Reboot |

**Notfall-Plan (immer haben):**

- Zweites Gerät (Handy/Laptop) mit SSH-Zugriff auf den Host. Beim ersten Aufsetzen `sshd` installieren und aktivieren, **bevor** der erste VM-Start passiert.
- Kommando-Cheatsheet (auf dem Handy):
  - `sudo virsh destroy win`
  - `sudo /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh`
  - `sudo systemctl start sddm`

---

## 10. Was später optimiert werden kann (nicht jetzt)

- **CPU-Governor**: auf `performance` setzen für stabile Frametimes.
- **systemd-CPU-Affinity**: System-Services hart auf CCD1 zwingen (`systemd.cpu_affinity=8-15,24-31` in Cmdline), falls Frametimes zucken.
- **Looking-Glass mit iGPU**: wenn der Komfortverlust irgendwann doch nervt, ist der Wechsel zu Dual-GPU (iGPU als Host) klein — die VM-XML bleibt fast unverändert.
- **VFIO-PCI early bind via initramfs**: nur sinnvoll bei Dual-GPU. Hier nicht.
