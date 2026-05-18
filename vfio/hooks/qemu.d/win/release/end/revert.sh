#!/usr/bin/env bash
# Post-Stop-Hook fuer Single-GPU-Passthrough.
# Wird von libvirt aufgerufen, nachdem die VM heruntergefahren ist.
#
# Aufgaben:
#   1. Devices von vfio-pci entbinden
#   2. vfio-Module entladen
#   3. Nvidia-Module wieder laden
#   4. Display-Manager (sddm) wieder starten
#
# Wird auch vom Pre-Start-Hook als Cleanup aufgerufen, falls dieser
# scheitert. Daher set +e: jeder Schritt soll versucht werden, auch
# wenn andere fehlschlagen.

set +e

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
        current_driver=$(basename "$(readlink /sys/bus/pci/devices/$dev/driver)")
        if [[ "$current_driver" == "vfio-pci" ]]; then
            echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
        fi
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

# Nvidia bindet sich von selbst an die GPU. Die USB-Controller laesst der
# Kernel ueber den xhci-Treiber automatisch neu enumerieren.
sleep 1

echo "[hook] Display-Manager starten…"
systemctl start sddm

echo "[hook] Revert fertig."
