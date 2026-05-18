#!/usr/bin/env bash
# Post-Stop-Skript fuer Single-GPU-Passthrough.
#
# Wird von libvirt als release/end-Hook automatisch aufgerufen, NACHDEM
# die VM heruntergefahren ist. Auch vom start.sh als Cleanup, falls
# Pre-Start scheitert.
#
# Aufgaben:
#   1. driver_override auf allen Devices clearen
#   2. Devices von vfio-pci entbinden
#   3. vfio-Module entladen
#   4. Nvidia-Module laden
#   5. Devices manuell an ihre Original-Treiber binden
#   6. Display-Manager (sddm) wieder starten
#
# set +e: jeder Schritt wird versucht, auch wenn andere fehlschlagen.
# Recovery muss best-effort sein.

set +e

GPU_PCI="0000:01:00.0"
GPU_AUDIO_PCI="0000:01:00.1"
USB_GROUP22="0000:13:00.0"
USB_GROUP27="0000:77:00.0"
USB_GROUP32="0000:79:00.4"

# Devices -> Original-Treiber
declare -A ORIGINAL_DRIVER=(
    ["$GPU_PCI"]="nvidia"
    ["$GPU_AUDIO_PCI"]="snd_hda_intel"
    ["$USB_GROUP22"]="xhci_hcd"
    ["$USB_GROUP27"]="xhci_hcd"
    ["$USB_GROUP32"]="xhci_hcd"
)

ALL_DEVICES=("$GPU_PCI" "$GPU_AUDIO_PCI" "$USB_GROUP22" "$USB_GROUP27" "$USB_GROUP32")

log() { echo "[revert] $*"; }

log "driver_override clearen + von vfio-pci entbinden…"
for dev in "${ALL_DEVICES[@]}"; do
    # driver_override auf leer setzen (sonst klebt vfio-pci)
    echo "" > /sys/bus/pci/devices/$dev/driver_override 2>/dev/null
    # Entbinden falls noch vfio-pci
    if [[ -L /sys/bus/pci/devices/$dev/driver ]]; then
        current_driver=$(basename "$(readlink /sys/bus/pci/devices/$dev/driver)")
        if [[ "$current_driver" == "vfio-pci" ]]; then
            echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
        fi
    fi
done

log "vfio-Module entladen…"
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

log "Nvidia-Module laden…"
modprobe nvidia
modprobe nvidia_modeset
modprobe nvidia_drm modeset=1
modprobe nvidia_uvm

# Kurz warten, damit Treiber initialisieren
sleep 1

log "Devices an Original-Treiber binden…"
for dev in "${ALL_DEVICES[@]}"; do
    drv="${ORIGINAL_DRIVER[$dev]}"
    if [[ -L /sys/bus/pci/devices/$dev/driver ]]; then
        log "  $dev ist schon gebunden ($(basename $(readlink /sys/bus/pci/devices/$dev/driver)))"
        continue
    fi
    if [[ -d "/sys/bus/pci/drivers/$drv" ]]; then
        log "  $dev → $drv"
        echo "$dev" > "/sys/bus/pci/drivers/$drv/bind" 2>/dev/null
    else
        log "  WARNUNG: Treiber $drv nicht gefunden, $dev bleibt unbound"
    fi
done

log "Display-Manager starten…"
systemctl start sddm

# GPU-Daemons, die in start.sh gestoppt wurden, wieder hochziehen
GPU_DAEMONS=(coolercontrold lactd)
log "GPU-System-Daemons wieder starten…"
for svc in "${GPU_DAEMONS[@]}"; do
    if systemctl list-unit-files --no-legend --type=service 2>/dev/null \
        | awk '{print $1}' | grep -qx "${svc}.service"; then
        log "  → systemctl start $svc"
        systemctl start "$svc" || true
    fi
done

log "Revert fertig."
