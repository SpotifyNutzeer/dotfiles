#!/usr/bin/env bash
# Wrapper, der die Single-GPU-VM startet.
#
# Hintergrund: bei managed='no' im hostdev-Block prueft libvirt VOR
# jedem virsh start, ob alle Devices bereits an vfio-pci gebunden sind.
# Wenn nicht, scheitert virsh start, bevor der prepare/begin-Hook
# aufgerufen wird. Daher rufen wir das pre-start-Skript manuell auf,
# bevor wir virsh start ausfuehren.
#
# Self-Detach: der Pre-Start-Hook stoppt sddm, das beendet Hyprland
# und damit auch das Terminal, aus dem dieser Wrapper aufgerufen
# wurde. setsid/nohup reichen nicht, weil systemd die user.slice
# per cgroup abraeumt. Loesung: das Skript exec'ed sich selbst als
# transient systemd-System-Unit — die haengt nicht an der User-Session.
#
# Beim VM-Stop laeuft revert.sh automatisch ueber den
# release/end-Hook von libvirt — kein Wrapper-Teil dafuer noetig.

set -e

if [[ -z "${VFIO_DETACHED:-}" ]]; then
    echo "[wrap] Detache in systemd-System-Unit 'vfio-win'…"
    echo "[wrap] Logs folgen (z.B. via SSH oder TTY): journalctl -u vfio-win -f"
    exec sudo systemd-run \
        --collect \
        --unit=vfio-win \
        --description="VFIO single-GPU passthrough start" \
        --setenv=VFIO_DETACHED=1 \
        bash "$(realpath "$0")"
fi

# Ab hier: detached, laeuft als root unter systemd — kein sudo mehr noetig.

HOOK_PRE="/etc/libvirt/hooks/qemu.d/win/prepare/begin/start.sh"
HOOK_REVERT="/etc/libvirt/hooks/qemu.d/win/release/end/revert.sh"
VM_NAME="win"

if [[ ! -x "$HOOK_PRE" ]]; then
    echo "FEHLER: $HOOK_PRE nicht vorhanden oder nicht ausfuehrbar." >&2
    exit 1
fi

# Kein lsof-Check: unter Wayland+Nvidia haelt der Compositor permanent
# /dev/nvidia* offen, der Check waere immer positiv. Der Pre-Start-Hook
# stoppt sddm und killt im Notfall Reste mit SIGTERM/SIGKILL.
# Achtung: laufende Spiele/Apps werden ohne Warnung beendet.

echo "[wrap] Pre-Start-Hook ausfuehren…"
"$HOOK_PRE"

echo "[wrap] libvirt: VM starten…"
if ! virsh -c qemu:///system start "$VM_NAME"; then
    echo "[wrap] virsh start gescheitert, triggere Revert…" >&2
    "$HOOK_REVERT"
    exit 1
fi

echo "[wrap] VM gestartet. Display kommt nach ~30 s mit Windows."
echo "[wrap] VM herunterfahren in Windows triggert automatisch den Revert."
