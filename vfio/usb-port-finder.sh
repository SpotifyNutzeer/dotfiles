#!/usr/bin/env bash
# usb-port-finder.sh
#
# Identifiziere, welche physischen USB-Ports am Mainboard zu welchem
# USB-Controller (und damit IOMMU-Gruppe) gehoeren.
#
# Hintergrund: Beim PCIe-Passthrough eines USB-Controllers wandern alle
# Devices, die an dessen physischen Ports haengen, automatisch in die VM.
# Um die richtigen Ports zu identifizieren, muss man pro Port testen,
# zu welchem Controller er gehoert.
#
# Bedienung:
#   1. Skript starten
#   2. Geraet in einen physischen USB-Port stecken
#   3. Auf der Konsole ablesen: "IOMMU Group X"
#   4. Wenn X eine deiner Ziel-Gruppen ist -> Port markieren (Aufkleber)
#   5. Wiederholen fuer alle Ports
#   6. Strg+C zum Beenden

set -uo pipefail

# Diese IOMMU-Gruppen werden als "interessant" markiert (Kandidaten fuer
# VM-Controller-Passthrough). Anpassen falls noetig.
TARGET_GROUPS=(31 34)

declare -A BUS_PCI BUS_GROUP BUS_SPEED BUS_DEVICES

build_bus_map() {
    BUS_PCI=()
    BUS_GROUP=()
    BUS_SPEED=()
    BUS_DEVICES=()
    for bus in /sys/bus/usb/devices/usb*; do
        [[ -d "$bus" ]] || continue
        bnum="${bus##*/usb}"
        pci=$(readlink -f "$bus/.." | grep -oE '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]' | tail -1)
        group=$(readlink "/sys/bus/pci/devices/$pci/iommu_group" 2>/dev/null | xargs -r basename || echo "?")
        speed=$(cat "$bus/speed" 2>/dev/null || echo "?")
        BUS_PCI[$bnum]=$pci
        BUS_GROUP[$bnum]=$group
        BUS_SPEED[$bnum]=$speed
        BUS_DEVICES[$bnum]=""
    done

    # Pro Bus die aktuell angeschlossenen Devices sammeln (ohne Root-Hubs,
    # ohne Interfaces). Devicepfade heissen z.B. "3-2", "3-2.1" usw.
    for dev in /sys/bus/usb/devices/*-*; do
        [[ -d "$dev" ]] || continue
        devname=$(basename "$dev")
        # Interfaces haben ':' im Namen (z.B. 3-2:1.0) -> ueberspringen
        [[ "$devname" == *:* ]] && continue
        bus="${devname%%-*}"
        [[ -z "${BUS_PCI[$bus]:-}" ]] && continue
        vid=$(cat "$dev/idVendor" 2>/dev/null || echo "")
        pid=$(cat "$dev/idProduct" 2>/dev/null || echo "")
        manuf=$(cat "$dev/manufacturer" 2>/dev/null || echo "")
        prod=$(cat "$dev/product" 2>/dev/null || echo "")
        # Mindestens eine sinnvolle Info muss da sein
        [[ -z "$manuf" && -z "$prod" && -z "$vid" ]] && continue
        label="$manuf $prod"
        label="${label## }"; label="${label%% }"
        [[ -z "$label" ]] && label="(unbekannt)"
        BUS_DEVICES[$bus]+="        - ${label} [${vid}:${pid}]"$'\n'
    done
}

is_target_group() {
    local g="$1"
    for t in "${TARGET_GROUPS[@]}"; do
        [[ "$g" == "$t" ]] && return 0
    done
    return 1
}

print_controllers() {
    echo "=== USB-Controller-Uebersicht ==="
    for bnum in $(printf '%s\n' "${!BUS_PCI[@]}" | sort -n); do
        local note=""
        if is_target_group "${BUS_GROUP[$bnum]}"; then
            note="   >>> Ziel-Controller fuer VM <<<"
        fi
        printf "Bus %-3s | PCI %-13s | IOMMU Group %-3s | %sM%s\n" \
            "$bnum" "${BUS_PCI[$bnum]}" "${BUS_GROUP[$bnum]}" \
            "${BUS_SPEED[$bnum]}" "$note"
        if [[ -n "${BUS_DEVICES[$bnum]}" ]]; then
            printf "%s" "${BUS_DEVICES[$bnum]}"
        else
            echo "        (keine Geraete angeschlossen)"
        fi
    done
    echo ""
}

build_bus_map
print_controllers

echo "=== Live-Modus ==="
echo "Stecke jetzt nacheinander deine USB-Geraete in verschiedene physische Ports."
echo "Bei jedem ADD-Event wird unten angezeigt, zu welchem Controller der Port gehoert."
echo "Wenn 'IOMMU Group' eine deiner Ziel-Gruppen ist (${TARGET_GROUPS[*]}), markiere"
echo "den Port physisch (Aufkleber/Notiz)."
echo ""
echo "Strg+C zum Beenden."
echo ""

# udevadm monitor liefert Live-Events. Wir filtern auf USB-Devices mit
# Bus-Nummer im Pfad (usbN/N-M).
udevadm monitor --subsystem-match=usb --udev 2>/dev/null | \
while IFS= read -r line; do
    # Zeilenformat: "UDEV  [timestamp] add  /devices/.../usbN/N-M ..."
    if [[ "$line" =~ UDEV[[:space:]]+\[[^\]]+\][[:space:]]+(add|remove)[[:space:]]+(/devices/[^[:space:]]*/usb([0-9]+)/[0-9]+-[0-9.]+)([[:space:]]|$) ]]; then
        action="${BASH_REMATCH[1]}"
        devpath="${BASH_REMATCH[2]}"
        bus="${BASH_REMATCH[3]}"
        pci="${BUS_PCI[$bus]:-?}"
        group="${BUS_GROUP[$bus]:-?}"

        marker=""
        if is_target_group "$group"; then
            marker="  >>> ZIEL-CONTROLLER <<<"
        fi

        if [[ "$action" == "add" ]]; then
            # Kurz warten, bis Kernel die Device-Attribute geschrieben hat
            sleep 0.3
            vid="????"; pid="????"; manuf=""; prod=""
            if [[ -r "/sys${devpath}/idVendor" ]]; then
                vid=$(cat "/sys${devpath}/idVendor" 2>/dev/null || echo "????")
                pid=$(cat "/sys${devpath}/idProduct" 2>/dev/null || echo "????")
                manuf=$(cat "/sys${devpath}/manufacturer" 2>/dev/null || echo "")
                prod=$(cat "/sys${devpath}/product" 2>/dev/null || echo "")
            fi
            printf "[+] Bus %s | IOMMU Group %s | %s:%s | %s %s%s\n" \
                "$bus" "$group" "$vid" "$pid" "$manuf" "$prod" "$marker"
        else
            printf "[-] Bus %s | IOMMU Group %s%s\n" "$bus" "$group" "$marker"
        fi
    fi
done
