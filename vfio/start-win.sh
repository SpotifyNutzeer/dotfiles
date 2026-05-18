#!/usr/bin/env bash
# Wrapper, der die Single-GPU-VM startet.
#
# Hintergrund: bei managed='no' im hostdev-Block prueft libvirt VOR
# jedem virsh start, ob alle Devices bereits an vfio-pci gebunden sind.
# Wenn nicht, scheitert virsh start, bevor der prepare/begin-Hook
# aufgerufen wird. Daher rufen wir das pre-start-Skript manuell auf,
# bevor wir virsh start ausfuehren.
#
# Beim VM-Stop laeuft revert.sh automatisch ueber den
# release/end-Hook von libvirt — kein Wrapper-Teil dafuer noetig.

set -e

HOOK_PRE="/etc/libvirt/hooks/qemu.d/win/prepare/begin/start.sh"
HOOK_REVERT="/etc/libvirt/hooks/qemu.d/win/release/end/revert.sh"
VM_NAME="win"

if [[ ! -x "$HOOK_PRE" ]]; then
    echo "FEHLER: $HOOK_PRE nicht vorhanden oder nicht ausfuehrbar." >&2
    exit 1
fi

# Sanity-Check: GPU darf nicht von Apps genutzt werden
if command -v lsof >/dev/null; then
    holders=$(sudo lsof /dev/nvidia* 2>/dev/null | tail -n +2 || true)
    if [[ -n "$holders" ]]; then
        echo "FEHLER: GPU wird noch von folgenden Prozessen genutzt:" >&2
        echo "$holders" >&2
        echo "Bitte alle GPU-Apps (Browser, Discord, Steam, …) schliessen." >&2
        exit 1
    fi
fi

echo "[wrap] Pre-Start-Hook manuell ausfuehren…"
sudo "$HOOK_PRE"

echo "[wrap] libvirt: VM starten…"
if ! virsh -c qemu:///system start "$VM_NAME"; then
    echo "[wrap] virsh start gescheitert, triggere Revert…" >&2
    sudo "$HOOK_REVERT"
    exit 1
fi

echo "[wrap] VM gestartet. Display kommt nach ~30 s mit Windows."
echo "[wrap] VM herunterfahren in Windows triggert automatisch den Revert."
