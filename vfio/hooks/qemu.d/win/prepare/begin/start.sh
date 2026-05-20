#!/usr/bin/env bash
# Pre-Start-Skript fuer Single-GPU-Passthrough.
#
# Wird in der jetzigen Konfiguration NICHT von libvirt aufgerufen
# (managed='no' scheitert in der Validation, bevor libvirt zum Hook
# kommt). Stattdessen ruft der Wrapper start-win.sh dieses Skript
# manuell auf, BEVOR er virsh start ausfuehrt.
#
# Aufgaben:
#   1. Display-Manager (sddm) stoppen
#   2. User-Sessions auf seat0 terminieren (Hyprland & Co. halten /dev/dri/*)
#   3. Warten, bis /dev/nvidia* und /dev/dri/* freigegeben sind
#   4. Auf TTY wechseln, EFI-Framebuffer entbinden
#   5. Nvidia-Module entladen (Reihenfolge wichtig)
#   6. vfio-Module laden
#   7. GPU, GPU-Audio und USB-Controller an vfio-pci binden
#
# Bei Fehler: Revert-Skript aufrufen.

set -e

GPU_PCI="0000:01:00.0"
GPU_AUDIO_PCI="0000:01:00.1"
USB_GROUP22="0000:13:00.0"
USB_GROUP27="0000:77:00.0"
USB_GROUP32="0000:79:00.4"

ALL_DEVICES=(
    "$GPU_PCI" "$GPU_AUDIO_PCI"
    "$USB_GROUP22" "$USB_GROUP27" "$USB_GROUP32"
)

trap 'echo "[hook] FEHLER, triggere Revert…" >&2; /etc/libvirt/hooks/qemu.d/win/release/end/revert.sh || true; exit 1' ERR

log() { echo "[start] $*"; }

# System-Daemons, die die GPU offen halten und stoppt werden muessen.
# Werden im revert.sh wieder gestartet.
GPU_DAEMONS=(coolercontrold lactd)

log "GPU-System-Daemons stoppen…"
for svc in "${GPU_DAEMONS[@]}"; do
    if systemctl is-active "$svc" >/dev/null 2>&1; then
        log "  → systemctl stop $svc"
        systemctl stop "$svc"
    fi
done

log "Display-Manager stoppen…"
systemctl stop sddm

log "Warte, bis sddm-Service inaktiv ist…"
for _ in {1..20}; do
    systemctl is-active sddm >/dev/null 2>&1 || break
    sleep 0.5
done

# sddm-Stop beendet nur den Greeter. Die User-Session (Hyprland, Xwayland,
# kitty, quickshell) laeuft unter user@.service auf seat0 weiter und haelt
# /dev/dri/cardN offen — das blockiert spaeter nvidia_drm unload.
# SSH-Sessions haben keinen Seat und bleiben unangetastet.
log "User-Sessions auf seat0 terminieren…"
mapfile -t sessions < <(loginctl list-sessions --no-legend 2>/dev/null | awk '$4 == "seat0" {print $1}')
for sess in "${sessions[@]}"; do
    [[ -n "$sess" ]] || continue
    log "  → loginctl terminate-session $sess"
    loginctl terminate-session "$sess" 2>/dev/null || true
done

log "Warte, bis /dev/nvidia* und /dev/dri/* freigegeben sind…"
for _ in {1..60}; do
    if ! lsof /dev/nvidia* /dev/dri/* 2>/dev/null | grep -q .; then
        break
    fi
    sleep 0.5
done

# Falls noch Prozesse haengen: kill (Hyprland-Kinder, die loginctl nicht
# schnell genug abgeraeumt hat)
if lsof /dev/nvidia* /dev/dri/* 2>/dev/null | tail -n +2 | awk '{print $2}' | sort -u > /tmp/nvidia-holders.$$; then
    if [[ -s /tmp/nvidia-holders.$$ ]]; then
        log "Restliche GPU/DRM-Halter werden gekillt…"
        while read -r pid; do
            kill -TERM "$pid" 2>/dev/null || true
        done < /tmp/nvidia-holders.$$
        sleep 2
        # Notfall SIGKILL
        while read -r pid; do
            kill -KILL "$pid" 2>/dev/null || true
        done < /tmp/nvidia-holders.$$
    fi
    rm -f /tmp/nvidia-holders.$$
fi

log "Auf TTY2 wechseln…"
chvt 2 || true

log "Framebuffer-Treiber entbinden…"
for drv_dir in /sys/bus/platform/drivers/efi-framebuffer /sys/bus/platform/drivers/simple-framebuffer; do
    [[ -d "$drv_dir" ]] || continue
    for fb in "$drv_dir"/*; do
        name=$(basename "$fb")
        [[ "$name" == "bind" || "$name" == "unbind" || "$name" == "uevent" || "$name" == "module" ]] && continue
        echo "$name" > "$drv_dir/unbind" 2>/dev/null || true
    done
done

log "Nvidia-Module entladen…"
# Reihenfolge wichtig: uvm → drm → modeset → nvidia
for mod in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do
    if lsmod | awk '{print $1}' | grep -qx "$mod"; then
        log "  → modprobe -r $mod"
        modprobe -r "$mod"
    fi
done

# Sicherheits-Check: alle Nvidia-Module wirklich weg?
if lsmod | awk '{print $1}' | grep -qE '^nvidia'; then
    log "FEHLER: Nvidia-Module noch geladen nach modprobe -r:"
    lsmod | grep '^nvidia'
    exit 1
fi

log "vfio-Module laden…"
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci

log "Devices an vfio-pci binden…"
for dev in "${ALL_DEVICES[@]}"; do
    # driver_override auf vfio-pci setzen (sorgt fuer "sticky" binding)
    echo "vfio-pci" > /sys/bus/pci/devices/$dev/driver_override

    # Aktuellen Treiber entbinden (falls vorhanden und nicht schon vfio-pci)
    if [[ -L /sys/bus/pci/devices/$dev/driver ]]; then
        current_driver=$(basename "$(readlink /sys/bus/pci/devices/$dev/driver)")
        if [[ "$current_driver" != "vfio-pci" ]]; then
            log "  → unbind $dev von $current_driver"
            echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
        fi
    fi

    # An vfio-pci binden
    if [[ ! -L /sys/bus/pci/devices/$dev/driver ]]; then
        log "  → bind $dev an vfio-pci"
        echo "$dev" > /sys/bus/pci/drivers/vfio-pci/bind
    fi
done

log "Pre-Start fertig. Devices sind an vfio-pci."
