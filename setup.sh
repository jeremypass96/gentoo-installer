#!/bin/bash
# This script automates the installation of Gentoo Linux with a distribution binary kernel.
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

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_not_chroot

# Test if we have a network connection using Google's public IP address.
ping -c 4 8.8.8.8 || die "Network unreachable (ping to Google's public DNS server failed)"

# Test HTTPS access and DNS resolution.
curl --location gentoo.org --output /dev/null || die "DNS or HTTPS failed (cannot reach gentoo.org)"

# Update the system clock.
chronyd -q

# Detect drive(s).
run_step "Detecting available disks..." true
mapfile -t DISKS < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}')

if [ "${#DISKS[@]}" -eq 0 ]; then
    if command -v dialog >/dev/null 2>&1; then
        dialog --clear --msgbox "ERROR: No disks detected. Aborting." 7 50
    else
        echo "ERROR: No disks detected. Aborting."
    fi
    exit 1
elif [ "${#DISKS[@]}" -eq 1 ]; then
    DRIVE="${DISKS[0]}"
    if command -v dialog >/dev/null 2>&1; then
        dialog --clear --msgbox "Automatically selected drive:\n\n$DRIVE" 8 50
    else
        echo ">>> Automatically selected drive: $DRIVE"
    fi
else
    if command -v dialog >/dev/null 2>&1; then
        MENU_ITEMS=()
        for dev in "${DISKS[@]}"; do
            info=$(lsblk -dpno SIZE,MODEL "$dev" | sed 's/  */ /g')
            MENU_ITEMS+=("$dev" "$info")
        done

        CHOSEN_DISK=$(
            dialog --clear \
                   --backtitle "Gentoo Install: Disk Selection" \
                   --title "Select target disk" \
                   --no-cancel \
                   --menu "Choose the disk to partition and install Gentoo on (THIS WILL BE WIPED!):" \
                   18 72 8 \
                   "${MENU_ITEMS[@]}" \
                   3>&1 1>&2 2>&3
        )
        clear

        DRIVE="$CHOSEN_DISK"
    else
        echo "Multiple disks detected:"
        lsblk -dpno NAME,SIZE,MODEL | grep -E "sd|hd|vd|nvme|mmc"
        read -r -p "Enter disk to use (example: /dev/sda or /dev/nvme0n1): " DRIVE
    fi
fi

pause_msg "TARGET DISK SELECTED:\n\n$DRIVE\n\nThis disk will be ERASED and repartitioned.\n\nIf this is NOT correct, stop now."
countdown 5

if [[ -d /sys/firmware/efi ]]; then
    pause_msg "UEFI detected.\n\nAbout to create a GPT partition table on:\n\n$DRIVE"

    run_step "Creating GPT partition table on $DRIVE..."
    parted -s "$DRIVE" mklabel gpt

    part() { [[ "$1" =~ [0-9]$ ]] && echo "${1}p$2" || echo "${1}$2"; }
    EFI_PARTITION="$(part "$DRIVE" 1)"
    ROOT_PARTITION="$(part "$DRIVE" 2)"

    pause_msg "Partitions that will be used:\n\nEFI:  $EFI_PARTITION\nROOT: $ROOT_PARTITION"

    run_step "Creating and formatting EFI system partition..."
    parted -s "$DRIVE" mkpart primary fat32 1MiB 1GiB

    run_step "Marking EFI partition as ESP..."
    parted -s "$DRIVE" set 1 esp on

    run_step "Formatting EFI partition (FAT32)..."
    mkfs.vfat -F 32 "$EFI_PARTITION"

    run_step "Creating and formatting root partition..."
    parted -s "$DRIVE" mkpart primary xfs 1GiB 100%

    run_step "Formatting root partition (XFS)..."
    mkfs.xfs -f "$ROOT_PARTITION"

    run_step "Creating /mnt/gentoo..."
    mkdir -p /mnt/gentoo

    run_step "Mounting root partition to /mnt/gentoo..."
    mount "$ROOT_PARTITION" /mnt/gentoo

    run_step "Mounting EFI system partition..."
    mkdir -p /mnt/gentoo/boot/efi
    mount "$EFI_PARTITION" /mnt/gentoo/boot/efi

    pause_msg "Disk prep complete.\n\nMounted:\nROOT -> /mnt/gentoo\nEFI  -> /mnt/gentoo/boot/efi"
else
    pause_msg "BIOS detected.\n\nAbout to create an MBR partition table on:\n\n$DRIVE"

    run_step "Creating MBR partition table on $DRIVE..."
    parted -s "$DRIVE" mklabel msdos

    BOOT_PARTITION="${DRIVE}1"
    ROOT_PARTITION="${DRIVE}2"

    pause_msg "Partitions that will be used:\n\nBOOT: $BOOT_PARTITION\nROOT: $ROOT_PARTITION"

    run_step "Creating and formatting boot partition..."
    parted -s "$DRIVE" mkpart primary xfs 1MiB 1GiB

    run_step "Setting boot flag..."
    parted -s "$DRIVE" set 1 boot on

    run_step "Formatting boot partition (XFS)..."
    mkfs.xfs -f "$BOOT_PARTITION"

    run_step "Creating and formatting root partition..."
    parted -s "$DRIVE" mkpart primary xfs 1GiB 100%

    run_step "Formatting root partition (XFS)..."
    mkfs.xfs -f "$ROOT_PARTITION"

    run_step "Creating /mnt/gentoo..."
    mkdir -p /mnt/gentoo

    run_step "Mounting root partition to /mnt/gentoo..."
    mount "$ROOT_PARTITION" /mnt/gentoo

    run_step "Creating /mnt/gentoo/boot..."
    mkdir -p /mnt/gentoo/boot

    run_step "Mounting boot partition to /mnt/gentoo/boot..."
    mount "$BOOT_PARTITION" /mnt/gentoo/boot

    pause_msg "Disk prep complete.\n\nMounted:\nROOT -> /mnt/gentoo\nBOOT -> /mnt/gentoo/boot"
fi

# Generate fstab.
FSTAB_CONTENT=$(genfstab /mnt/gentoo)

if command -v dialog >/dev/null 2>&1; then
    dialog --clear \
           --backtitle "Gentoo Install: fstab Generation" \
           --title "Preview of /etc/fstab" \
           --msgbox "$FSTAB_CONTENT" 18 80
else
    echo ">>> Preview of /etc/fstab:"
    echo "$FSTAB_CONTENT"
fi

genfstab /mnt/gentoo > /mnt/gentoo/etc/fstab

if command -v dialog >/dev/null 2>&1; then
    dialog --clear --msgbox "fstab successfully generated." 6 40
else
    echo ">>> fstab successfully generated."
fi

# Make swapfile and activate it.
SWAP_SIZE_GB=8

if command -v dialog >/dev/null 2>&1; then
    CHOSEN_SWAP=$(
        dialog --clear \
               --backtitle "Gentoo Install: Swapfile" \
               --title "Swapfile size" \
               --menu "Select swapfile size (GB):" 15 35 5 \
               2 "2 GB" \
               4 "4 GB" \
               6 "6 GB" \
               8 "8 GB (default)" \
               10 "10 GB" \
               12 "12 GB" \
               14 "14 GB" \
               16 "16 GB" \
               3>&1 1>&2 2>&3
    )
    clear

    # If user pressed ESC, keep default.
    if [ -n "$CHOSEN_SWAP" ]; then
        SWAP_SIZE_GB="$CHOSEN_SWAP"
    fi
else
    read -r -p "Swapfile size in GB [8]: " INPUT_SWAP
    case "$INPUT_SWAP" in
        "" )  ;;              # keep default
        * )  SWAP_SIZE_GB="$INPUT_SWAP" ;;
    esac
fi

if [ "$SWAP_SIZE_GB" -gt 0 ]; then
        TOTAL_BYTES=$((SWAP_SIZE_GB * 1024 * 1024 * 1024))
        COUNT_MB=$((SWAP_SIZE_GB * 1024))

            (
                dd if=/dev/zero of=/mnt/gentoo/swapfile bs=1M count="$COUNT_MB" status=none &
                DD_PID=$!

                while kill -0 "$DD_PID" 2>/dev/null; do
                    BYTES_WRITTEN=$(stat -c %s /mnt/gentoo/swapfile 2>/dev/null || echo 0)
                    PERCENT=$(( BYTES_WRITTEN * 100 / TOTAL_BYTES ))
                    echo "$PERCENT"
                    sleep 0.05
                done

                wait "$DD_PID"
                echo 100
            ) | dialog --gauge "Creating ${SWAP_SIZE_GB} GB swapfile..." 7 35 0
            dialog --msgbox "Created ${SWAP_SIZE_GB} GB swapfile." 6 28

            chmod 600 /mnt/gentoo/swapfile
            mkswap /mnt/gentoo/swapfile
            swapon /mnt/gentoo/swapfile
fi

clear

# Copy scripts to /mnt/gentoo before chroot'ing.
mkdir -p /mnt/gentoo/gentoo-installer
cp -rv "$SCRIPT_DIR"/pt2.sh /mnt/gentoo/gentoo-installer
cp -rv "$SCRIPT_DIR"/pt3.sh /mnt/gentoo/gentoo-installer
mkdir -p /mnt/gentoo/gentoo-installer/modules
cp -v "$SCRIPT_DIR"/modules/*.sh /mnt/gentoo/gentoo-installer/modules

# Enter the /mnt/gentoo directory.
cd /mnt/gentoo || exit

# Download and extract the Gentoo stage3 tarball.
BASEURL="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc"
LATEST_TXT="${BASEURL}/latest-stage3-amd64-desktop-openrc.txt"

echo ">>> Detecting latest stage3 tarball..."
STAGE3=$(wget -qO- "${LATEST_TXT}" | awk '/^stage3-amd64-desktop-openrc-/ {print $1; exit}')

echo ">>> Latest stage3 is: ${STAGE3}"
echo ">>> Downloading stage3 and checksums..."
wget "${BASEURL}/${STAGE3}"
wget "${BASEURL}/${STAGE3}.CONTENTS.gz"
wget "${BASEURL}/${STAGE3}.sha256"
wget "${BASEURL}/${STAGE3}.DIGESTS"
wget "${BASEURL}/${STAGE3}.asc"

echo ">>> Verifying stage3 checksums..."
sha256sum --check "${STAGE3}.sha256"
gpg --import /usr/share/openpgp-keys/gentoo-release.asc
gpg --verify "${STAGE3}.asc"
gpg --output "${STAGE3}.DIGESTS.verified" --verify "${STAGE3}.DIGESTS"
gpg --output "${STAGE3}.sha256.verified" --verify  "${STAGE3}.sha256"

echo ">>> Extracting stage3 tarball..."
UNPACK_SIZE=$(xz --robot -lv "${STAGE3}" | awk -F'\t' '$1=="totals" {print $5}')
xz -dc "${STAGE3}" | pv -s "${UNPACK_SIZE}" -pterb | tar xpf - --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

# Copy DNS info to the new system.
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

echo "This ends part 1 of the Gentoo installation script. Run ./pt2.sh for part 2."

echo ">>> Chroot'ing into the Gentoo install..."
# Chroot into the new environment (also mounts filesystems).
arch-chroot /mnt/gentoo
