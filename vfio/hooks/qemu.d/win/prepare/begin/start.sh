#!/usr/bin/env bash
# Pre-Start-Hook fuer Single-GPU-Passthrough.
# Wird von libvirt direkt vor dem QEMU-Start aufgerufen.
#
# Aufgaben:
#   1. Display-Manager (sddm) stoppen, damit Nvidia-Treiber freigegeben wird
#   2. Auf TTY wechseln, EFI-Framebuffer entbinden
#   3. Nvidia-Module entladen (Reihenfolge wichtig)
#   4. vfio-Module laden
#   5. GPU, GPU-Audio und drei USB-Controller an vfio-pci binden
#
# Bei Fehler: Revert-Skript aufrufen, damit der Host nicht im halben
# Zustand sitzt.

set -e

# === Geraete-Liste ===
GPU_PCI="0000:01:00.0"          # RTX 4090
GPU_AUDIO_PCI="0000:01:00.1"    # GPU-HDMI-Audio
USB_GROUP22="0000:13:00.0"      # Chipset USB 3.x (hintere I/O)
USB_GROUP27="0000:77:00.0"      # ASMedia USB 3.2
USB_GROUP32="0000:79:00.4"      # AMD Raphael USB 3.1 (USB-C)

ALL_DEVICES=(
    "$GPU_PCI" "$GPU_AUDIO_PCI"
    "$USB_GROUP22" "$USB_GROUP27" "$USB_GROUP32"
)

# Bei Fehler: revert + abort
trap '/etc/libvirt/hooks/qemu.d/win/release/end/revert.sh || true; exit 1' ERR

echo "[hook] Display-Manager stoppen…"
systemctl stop sddm

# Warten bis sddm wirklich tot
for _ in {1..10}; do
    systemctl is-active sddm >/dev/null 2>&1 || break
    sleep 0.5
done

echo "[hook] Auf TTY2 wechseln…"
chvt 2 || true

echo "[hook] Framebuffer-Treiber entbinden…"
if [[ -d /sys/bus/platform/drivers/efi-framebuffer ]]; then
    for fb in /sys/bus/platform/drivers/efi-framebuffer/*; do
        name=$(basename "$fb")
        [[ "$name" == "bind" || "$name" == "unbind" || "$name" == "uevent" ]] && continue
        echo "$name" > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true
    done
fi
if [[ -d /sys/bus/platform/drivers/simple-framebuffer ]]; then
    for fb in /sys/bus/platform/drivers/simple-framebuffer/*; do
        name=$(basename "$fb")
        [[ "$name" == "bind" || "$name" == "unbind" || "$name" == "uevent" ]] && continue
        echo "$name" > /sys/bus/platform/drivers/simple-framebuffer/unbind 2>/dev/null || true
    done
fi

echo "[hook] Nvidia-Module entladen…"
modprobe -r nvidia_uvm   || true
modprobe -r nvidia_drm   || true
modprobe -r nvidia_modeset || true
modprobe -r nvidia       || true

echo "[hook] vfio-Module laden…"
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci

echo "[hook] Devices an vfio-pci binden…"
for dev in "${ALL_DEVICES[@]}"; do
    vendor=$(cat /sys/bus/pci/devices/$dev/vendor)
    device=$(cat /sys/bus/pci/devices/$dev/device)
    # Aktuellen Treiber entbinden, falls vorhanden
    if [[ -L /sys/bus/pci/devices/$dev/driver ]]; then
        current_driver=$(basename "$(readlink /sys/bus/pci/devices/$dev/driver)")
        if [[ "$current_driver" != "vfio-pci" ]]; then
            echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
        fi
    fi
    # vfio-pci als neuen Treiber registrieren und binden (idempotent)
    echo "${vendor#0x} ${device#0x}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
    if [[ ! -L /sys/bus/pci/devices/$dev/driver ]]; then
        echo "$dev" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
    fi
done

echo "[hook] Pre-Start fertig, libvirt kann QEMU starten."
