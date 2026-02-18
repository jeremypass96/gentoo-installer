#!/bin/bash
# gpu-autodetect.sh — Gentoo installer module for GPU detection and VIDEO_CARDS configuration.
# Copyright (C) 2026 Jeremy Passarelli <recordguy96@aol.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# -----------------------------------------------------------
# Gentoo Installer: VIDEO_CARDS Autoconfig (GPU-aware)
# -----------------------------------------------------------
# - Detects GPU via lspci.
# - For AMD, maps to the correct Radeon family per Gentoo wiki:
#     R100, R200, R300–R500, R600–R700–Evergreen–NI,
#     Southern Islands, Sea Islands
# - For NVIDIA/Intel, sets sane defaults.
# - Writes: /etc/portage/package.use/00video
#   as: */* VIDEO_CARDS: -* <flags>.
# If detection is ambiguous (esp. older AMD), it asks you.
# -----------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "$1")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# Ensure lspci exists
if ! command -v lspci >/dev/null 2>&1; then
    echo ">>> sys-apps/pciutils (lspci) not found, emerging..."
    emerge -1q sys-apps/pciutils || {
        echo "ERROR: Failed to install pciutils; cannot continue."
        exit 1
    }
fi

GPU_LINE=$(lspci -nn | grep -Ei 'VGA compatible controller|3D controller|Display controller' | head -n1)

if [ -z "$GPU_LINE" ]; then
    echo ">>> No GPU found via lspci. Not touching VIDEO_CARDS."
    exit 0
fi

echo ">>> Detected GPU:"
echo "    $GPU_LINE"
echo

GPU_VENDOR="unknown"
VIDEO_FLAGS=""

case "$GPU_LINE" in
    *VMware*|*SVGA\ II*|*vmwgfx*)
        GPU_VENDOR="vmware"
        VIDEO_FLAGS="vmware"
        ;;

    *VirtualBox*|*InnoTek*|*Oracle\ Corporation*|*VBoxVGA*|*VMSVGA*)
        GPU_VENDOR="virtualbox"
        VIDEO_FLAGS="vmware"
        ;;

    *Red\ Hat*|*QXL*|*Spice*)
        GPU_VENDOR="qxl"
        VIDEO_FLAGS="qxl"
        ;;

    *NVIDIA*|*GeForce*)
        GPU_VENDOR="nvidia"
        VIDEO_FLAGS="nvidia"
        ;;

    *Intel*|*\ Corporation\ UHD*|*\ Iris*|*HD\ Graphics*)
        GPU_VENDOR="intel"
        # Modern Intel per Gentoo docs
        VIDEO_FLAGS="intel i965 iris"
        ;;

    *AMD*|*ATI*)
        GPU_VENDOR="amd"
        ;;
esac

# ---------------------------
# AMD family selection (Radeon)
# ---------------------------

choose_amd_family() {
    local gpu_text="$1"
    local family=""
    local flags=""

    # Try some automatic matches first, based on Gentoo wiki table

    # Southern Islands: CAPE VERDE, PITCAIRN, TAHITI, OLAND, HAINAN
    if echo "$gpu_text" | grep -qi 'Cape Verde\|Pitcairn\|Tahiti\|Oland\|Hainan'; then
        family="Southern Islands"
        flags="radeon radeonsi"
        echo "x11-libs/libdrm video_cards_amdgpu" > /etc/portage/package.use/libdrm
        chmod go+r /etc/portage/package.use/libdrm
    fi

    # Sea Islands: BONAIRE, KABINI, MULLINS, KAVERI, HAWAII
    if echo "$gpu_text" | grep -qi 'Bonaire\|Kabini\|Mullins\|Kaveri\|Hawaii'; then
        family="Sea Islands"
        flags="radeon radeonsi"
        echo "x11-libs/libdrm video_cards_amdgpu" > /etc/portage/package.use/libdrm
        chmod go+r /etc/portage/package.use/libdrm
    fi

    if [ -n "$family" ]; then
        echo ">>> AMD GPU auto-classified as: $family"
        echo ">>> VIDEO_CARDS -> $flags"
        echo
        AMD_FAMILY="$family"
        VIDEO_FLAGS="$flags"
        return
    fi

    # If we reach here, we can't reliably guess – ask the user.

    echo ">>> Cannot safely determine exact AMD family from:"
    echo "    $gpu_text"
    echo ">>> Please choose the correct family according to the Gentoo wiki."
    echo

    if command -v dialog >/dev/null 2>&1; then
        local tmp
        tmp=$(mktemp)

        dialog --clear \
            --backtitle "Gentoo Installer" \
            --title "AMD / Radeon Family Selection" \
            --menu "Detected: $gpu_text\n\nSelect your GPU family (see Gentoo Radeon wiki):" \
            0 0 0 \
            r100 "R100 - Radeon 7xxx / 320-345 (very old)" \
            r200 "R200 - Radeon 8xxx–9250" \
            r300 "R300/R400/R500 - X1300–X2300 / HD2300 etc." \
            r600 "R600/R700/Evergreen/Northern Islands - HD2400–HD6990" \
            south "Southern Islands - HD77xx–79xx, R7 240–260, R9 270–280" \
            sea   "Sea Islands - Bonaire, Kabini, Kaveri, Hawaii, etc." \
            2>"$tmp"

        local choice
        choice=$(<"$tmp")
        rm -f "$tmp"
    else
        echo "1) R100        (Radeon 7xxx / 320-345)"
        echo "2) R200        (Radeon 8xxx–9250)"
        echo "3) R300–R500   (X1300–X2300 / HD2300 etc.)"
        echo "4) R600–NI     (HD2400–HD6990)"
        echo "5) Southern Islands (HD77xx–79xx, R7 240–260, R9 270–280)"
        echo "6) Sea Islands      (Bonaire, Kabini, Kaveri, Hawaii, ...)"
        read -rp "Enter choice [1-6]: " num
        case "$num" in
            1) choice="r100" ;;
            2) choice="r200" ;;
            3) choice="r300" ;;
            4) choice="r600" ;;
            5) choice="south" ;;
            6) choice="sea" ;;
            *) echo "Invalid choice"; exit 1 ;;
        esac
    fi

    case "$choice" in
        r100)
            AMD_FAMILY="R100"
            VIDEO_FLAGS="radeon r100"
            ;;
        r200)
            AMD_FAMILY="R200"
            VIDEO_FLAGS="radeon r200"
            ;;
        r300)
            AMD_FAMILY="R300-R500"
            VIDEO_FLAGS="radeon r300"
            ;;
        r600)
            AMD_FAMILY="R600/R700/Evergreen/Northern Islands"
            VIDEO_FLAGS="radeon r600"
            ;;
        south)
            AMD_FAMILY="Southern Islands"
            VIDEO_FLAGS="radeon radeonsi"
            ;;
        sea)
            AMD_FAMILY="Sea Islands"
            VIDEO_FLAGS="radeon radeonsi"
            ;;
        *)
            echo "ERROR: Unknown selection."
            exit 1
            ;;
    esac

    echo ">>> AMD family selected: $AMD_FAMILY"
    echo ">>> VIDEO_CARDS -> $VIDEO_FLAGS"
    echo
}

if [ "$GPU_VENDOR" = "amd" ]; then
    choose_amd_family "$GPU_LINE"
fi

if [ "$GPU_VENDOR" = "unknown" ]; then
    echo ">>> Unknown GPU vendor. Not modifying VIDEO_CARDS."
    exit 0
fi

if [ "$GPU_VENDOR" = "vmware" ]; then
    emerge -qv app-emulation/open-vm-tools
    rc-service vmware-tools start
    rc-update add vmware-tools
fi

if [ "$GPU_VENDOR" = "virtualbox" ]; then
    emerge -qv app-emulation/virtualbox-guest-additions
    rc-update add virtualbox-guest-additions
    rc-update add dbus
    rc-service virtualbox-guest-additions start
    gpasswd -a "$name" vboxguest
    modprobe vboxdrv
    echo vboxdrv > /etc/modules-load.d/virtualbox.conf
fi

# ---------------------------------------
# Write /etc/portage/package.use/00video.
# ---------------------------------------

echo ">>> Writing /etc/portage/package.use/00video ..."
cat <<EOF > /etc/portage/package.use/00video
*/* VIDEO_CARDS: -* $VIDEO_FLAGS
EOF
chmod go+r /etc/portage/package.use/00video
echo ">>> Final VIDEO_CARDS setting:"
cat /etc/portage/package.use/00video
echo
echo ">>> GPU / VIDEO_CARDS configuration complete."