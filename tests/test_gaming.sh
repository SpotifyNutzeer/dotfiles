#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./helpers.sh
source ../lib/common.sh
source ../lib/packages.sh
source ../lib/gaming.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- x3d-mode: schreibt den Modus in alle amd_x3d_mode-Knoten (Fake-sysfs) ---
mkdir -p "$tmp/sysfs/AMDI0101:00"
printf 'frequency' > "$tmp/sysfs/AMDI0101:00/amd_x3d_mode"

X3D_SYSFS="$tmp/sysfs" sh ../system/bin/x3d-mode cache
assert_eq "$(cat "$tmp/sysfs/AMDI0101:00/amd_x3d_mode")" "cache" \
    "x3d-mode cache schreibt den Modus ins sysfs"

X3D_SYSFS="$tmp/sysfs" sh ../system/bin/x3d-mode frequency
assert_eq "$(cat "$tmp/sysfs/AMDI0101:00/amd_x3d_mode")" "frequency" \
    "x3d-mode frequency schaltet zurück"

# --- x3d-mode: ungültiger Modus und fehlendes Gerät schlagen fehl ---
X3D_SYSFS="$tmp/sysfs" sh ../system/bin/x3d-mode turbo 2>/dev/null
assert_eq "$?" "1" "x3d-mode lehnt unbekannten Modus ab"
assert_eq "$(cat "$tmp/sysfs/AMDI0101:00/amd_x3d_mode")" "frequency" \
    "ungültiger Modus verändert das sysfs nicht"

X3D_SYSFS="$tmp/leer" sh ../system/bin/x3d-mode cache 2>/dev/null
assert_eq "$?" "1" "x3d-mode meldet fehlendes amd_x3d_vcache-Gerät"

# --- NVIDIA-Erkennung über $LSPCI (gefaktes lspci) ---
cat > "$tmp/lspci-nvidia" <<'EOF'
#!/bin/sh
echo "01:00.0 VGA compatible controller: NVIDIA Corporation AD102 [GeForce RTX 4090]"
EOF
cat > "$tmp/lspci-amd" <<'EOF'
#!/bin/sh
echo "10:00.0 VGA compatible controller: Advanced Micro Devices [AMD/ATI] Raphael"
echo "01:00.0 Ethernet controller: NVIDIA nForce"  # NVIDIA, aber keine GPU
EOF
chmod +x "$tmp/lspci-nvidia" "$tmp/lspci-amd"

LSPCI="$tmp/lspci-nvidia" _nvidia_gpu_present
assert_eq "$?" "0" "_nvidia_gpu_present erkennt NVIDIA-GPU"

LSPCI="$tmp/lspci-amd" _nvidia_gpu_present
assert_eq "$?" "1" "_nvidia_gpu_present ignoriert Nicht-GPU-NVIDIA-Geräte"

# --- Paketliste arch-nvidia.txt ist parsebar und enthält den lib32-Treiber ---
nvidia_pkgs="$(parse_package_list ../packages/arch-nvidia.txt | tr '\n' ' ')"
assert_contains "$nvidia_pkgs" "lib32-nvidia-utils" \
    "arch-nvidia.txt enthält lib32-nvidia-utils"
assert_contains "$nvidia_pkgs" "nvidia-open-dkms" \
    "arch-nvidia.txt enthält nvidia-open-dkms"

# --- gamemode.ini referenziert den installierten x3d-mode-Pfad ---
gm="$(cat ../.config/gamemode.ini)"
assert_contains "$gm" "/usr/local/bin/x3d-mode cache" \
    "gamemode.ini schaltet beim Start auf cache"
assert_contains "$gm" "/usr/local/bin/x3d-mode frequency" \
    "gamemode.ini schaltet am Ende zurück auf frequency"

finish
