#!/bin/bash
# This installer automates the installation of Gentoo Linux.
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_not_chroot

# Ensure dialog is available.
command -v dialog >/dev/null 2>&1 || die "The 'dialog' package is required to run this installer."

dialog --clear \
	--backtitle "Gentoo Linux Installer" \
	--title "Welcome" \
	--msgbox "Welcome to the Gentoo Linux Installer!

The installer will perform the following tasks:
- Verify network connectivity.
- Verify DNS resolution and HTTPS access.
- Synchronize the system clock.
- Detect and partition the target disk.
- Create the required filesystems.
- Mount the /boot and root partitions.
- Create a swapfile.
- Download and extract the latest stage3 tarball.
- Generate the fstab (using genfstab).
- Enter the installed system (chroot)." \
	17 53

# Test if we have a network connection using Google's public IP address.
run_step "Verifying network connectivity..." \
	ping -q -c 4 8.8.8.8 || die "Network unreachable (ping to Google's public DNS server failed)."

# Test HTTPS access and DNS resolution.
run_step "Verifying DNS resolution and HTTPS access..." \
	curl --location gentoo.org --output /dev/null || die "DNS or HTTPS failed (cannot reach gentoo.org)."

# Update the system clock.
run_step "Synchronizing the system clock with chrony..." \
	chronyd -q

# Detect drive(s).
run_step "Detecting available installation disks..." true
mapfile -t DISKS < <(lsblk -bdpno NAME,SIZE,TYPE | awk '$3=="disk" && $2>0 { print $1 }')

# Detect the disk we're currently booted from.
BOOT_SOURCE=$(findmnt -no SOURCE /)
BOOT_DISK=$(lsblk -ndo PKNAME "$BOOT_SOURCE" 2>/dev/null)

if [[ -n "$BOOT_DISK" ]]; then
	BOOT_DISK="/dev/$BOOT_DISK"
else
	BOOT_DISK="$BOOT_SOURCE"
fi

# Build a list of installation candidates (exclude the current boot disk).
INSTALL_DISKS=()

for disk in "${DISKS[@]}"; do
	[[ "$disk" == "$BOOT_DISK" ]] && continue
	INSTALL_DISKS+=("$disk")
done

if [ "${#INSTALL_DISKS[@]}" -eq 0 ]; then
	dialog --clear --backtitle "Gentoo Linux Installer" --title "No Installation Drive Found" --msgbox "No suitable installation drive was found.\nThe only detected drive appears to be the current boot device.\nThe installer will now exit." 7 66
	exit 1
elif [ "${#INSTALL_DISKS[@]}" -eq 1 ]; then
	DRIVE="${INSTALL_DISKS[0]}"
	SIZE=$(lsblk -dpno SIZE "$DRIVE")
	MODEL=$(lsblk -dpno MODEL "$DRIVE" | sed 's/^ *//')
	dialog --clear --msgbox \
		"Automatically selected drive:

			Device:	$DRIVE
			Size:	$SIZE
			Model:	$MODEL" \
		9 50
else
	MENU_ITEMS=()
	for dev in "${INSTALL_DISKS[@]}"; do
		info=$(lsblk -dpno SIZE,MODEL "$dev" | sed 's/  */ /g')
		MENU_ITEMS+=("$dev" "$info")
	done

	CHOSEN_DISK=$(
		dialog --clear \
			--backtitle "Gentoo Linux Installer" \
			--title "Disk Selection" \
			--no-cancel \
			--menu "Choose the disk to partition and install Gentoo onto (THIS WILL BE WIPED!):" \
			13 79 5 \
			"${MENU_ITEMS[@]}" \
			3>&1 1>&2 2>&3
	)
	clear

	DRIVE="$CHOSEN_DISK"
fi

if [[ -d /sys/firmware/efi ]]; then
	pause_msg "UEFI detected.\n\nI'm about to create a GPT partition table on this drive:\n\n$DRIVE"

	run_step "Creating GPT partition table on $DRIVE..." \
		parted -s "$DRIVE" mklabel gpt

	part() { [[ "$1" =~ [0-9]$ ]] && echo "${1}p$2" || echo "${1}$2"; }
	EFI_PARTITION="$(part "$DRIVE" 1)"
	ROOT_PARTITION="$(part "$DRIVE" 2)"

	pause_msg "Partitions that will be used:\n\nEFI:  $EFI_PARTITION\nROOT: $ROOT_PARTITION"

	run_step "Creating and formatting EFI system partition..." \
		parted -s "$DRIVE" mkpart primary fat32 1MiB 1GiB

	run_step "Marking EFI partition as ESP..." \
		parted -s "$DRIVE" set 1 esp on

	run_step "Formatting EFI partition (FAT32)..." \
		mkfs.vfat -F 32 "$EFI_PARTITION"

	run_step "Creating root partition..." \
		parted -s "$DRIVE" mkpart primary xfs 1GiB 100%

	run_step "Formatting root partition (XFS)..." \
		mkfs.xfs -f "$ROOT_PARTITION"

	run_step "Mounting root partition to /mnt/gentoo..." \
		mount --mkdir "$ROOT_PARTITION" /mnt/gentoo

	run_step "Mounting EFI system partition..." \
		mount --mkdir "$EFI_PARTITION" /mnt/gentoo/boot

	pause_msg "Disk prep complete.\n\nMounted:\nROOT -> /mnt/gentoo\nEFI  -> /mnt/gentoo/boot"
else
	pause_msg "BIOS detected.\n\n I'm about to create an MBR partition table on this drive:\n\n$DRIVE"

	run_step "Creating MBR partition table on $DRIVE..." \
		parted -s "$DRIVE" mklabel msdos

	part() { [[ "$1" =~ [0-9]$ ]] && echo "${1}p$2" || echo "${1}$2"; }
	BOOT_PARTITION="$(part "$DRIVE" 1)"
	ROOT_PARTITION="$(part "$DRIVE" 2)"

	pause_msg "Partitions that will be used:\n\nBOOT: $BOOT_PARTITION\nROOT: $ROOT_PARTITION"

	run_step "Creating boot partition..." \
		parted -s "$DRIVE" mkpart primary xfs 1MiB 1GiB

	run_step "Setting boot flag..." \
		parted -s "$DRIVE" set 1 boot on

	run_step "Formatting boot partition (XFS)..." \
		mkfs.xfs -f "$BOOT_PARTITION"

	run_step "Creating root partition..." \
		parted -s "$DRIVE" mkpart primary xfs 1GiB 100%

	run_step "Formatting root partition (XFS)..." \
		mkfs.xfs -f "$ROOT_PARTITION"

	run_step "Mounting root partition to /mnt/gentoo..." \
		mount --mkdir "$ROOT_PARTITION" /mnt/gentoo

	run_step "Mounting boot partition to /mnt/gentoo/boot..." \
		mount --mkdir "$BOOT_PARTITION" /mnt/gentoo/boot

	pause_msg "Disk prep complete.\n\nMounted:\nROOT -> /mnt/gentoo\nBOOT -> /mnt/gentoo/boot"
fi

# Make swapfile and activate it.
SWAP_SIZE_GB=8

CHOSEN_SWAP=$(
	dialog --clear \
		--backtitle "Gentoo Linux Installer" \
		--no-cancel \
		--title "Swapfile Size" \
		--menu "Select swapfile size (GB):" 15 30 5 \
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

if [ "$SWAP_SIZE_GB" -gt 0 ]; then
	TOTAL_BYTES=$((SWAP_SIZE_GB * 1024 * 1024 * 1024))
	COUNT_MB=$((SWAP_SIZE_GB * 1024))

	(
		dd if=/dev/zero of=/mnt/gentoo/swapfile bs=1M count="$COUNT_MB" status=none &
		DD_PID=$!

		while kill -0 "$DD_PID" 2>/dev/null; do
			BYTES_WRITTEN=$(stat -c %s /mnt/gentoo/swapfile 2>/dev/null || echo 0)
			PERCENT=$((BYTES_WRITTEN * 100 / TOTAL_BYTES))
			echo "$PERCENT"
			sleep 0.05
		done

		wait "$DD_PID"
		echo 100
	) | dialog --backtitle "Gentoo Linux Installer" --gauge "Creating ${SWAP_SIZE_GB} GB swapfile..." 6 32 0
	chmod 600 /mnt/gentoo/swapfile
	mkswap /mnt/gentoo/swapfile >/dev/null 2>&1 || die "Failed to initialize swapfile."
	swapon /mnt/gentoo/swapfile || die "Failed to activate swapfile."
	dialog --backtitle "Gentoo Linux Installer" --msgbox "Swapfile successfully created and activated!" 5 48
fi

clear

# Copy scripts to /mnt/gentoo before chroot'ing.
echo ">>> Copying configure script and module scripts into '/mnt/gentoo/gentoo-installer'..."
mkdir -p /mnt/gentoo/gentoo-installer
cp "$SCRIPT_DIR"/configure.sh /mnt/gentoo/gentoo-installer
mkdir -p /mnt/gentoo/gentoo-installer/modules
cp -r "$SCRIPT_DIR"/modules/*.sh /mnt/gentoo/gentoo-installer/modules

# Enter the /mnt/gentoo directory.
cd /mnt/gentoo || exit

# Download and extract the Gentoo stage3 tarball.
BASEURL="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc"
LATEST_TXT="${BASEURL}/latest-stage3-amd64-desktop-openrc.txt"

run_step "Detecting latest stage3 tarball..." true
STAGE3=$(wget -qO- "${LATEST_TXT}" | awk '/^stage3-amd64-desktop-openrc-/ {print $1; exit}')

dialog --backtitle "Gentoo Linux Installer" \
	--title "Latest Stage3" \
	--msgbox "The latest Gentoo stage3 tarball is:\n\n${STAGE3}" 7 55

echo ">>> Downloading stage3 tarball..."
wcurl --curl-options="--progress-bar" "${BASEURL}/${STAGE3}"
echo

echo ">>> Downloading checksums..."
wcurl --curl-options="--progress-bar" "${BASEURL}/${STAGE3}.CONTENTS.gz"
wcurl --curl-options="--progress-bar" "${BASEURL}/${STAGE3}.sha256"
wcurl --curl-options="--progress-bar" "${BASEURL}/${STAGE3}.DIGESTS"
wcurl --curl-options="--progress-bar" "${BASEURL}/${STAGE3}.asc"
echo

run_step "Verifying stage3 checksums..." \
	verify_stage3

echo ">>> Extracting stage3 tarball..."
UNPACK_SIZE=$(xz --robot -lv "${STAGE3}" | awk -F'\t' '$1=="totals" {print $5}')
xz -dc "${STAGE3}" | pv -s "${UNPACK_SIZE}" -pterb | tar xpf - --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

# Generate fstab.
FSTAB_CONTENT=$(genfstab /mnt/gentoo)

dialog --clear \
	--backtitle "Gentoo Linux Installer" \
	--title "Generated /etc/fstab" \
	--msgbox "$FSTAB_CONTENT" 0 0

printf '%s\n' "$FSTAB_CONTENT" >/mnt/gentoo/etc/fstab
sed -i '/^#/d;/^$/d' /mnt/gentoo/etc/fstab

dialog --clear --msgbox "/etc/fstab successfully generated." 6 40

# Copy DNS info to the new system.
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

echo ">>> The setup/bootstrap phase of the Gentoo installation is complete."
echo ">>> Run ./configure.sh to configure and finish installing Gentoo."

echo ">>> Chroot'ing into the Gentoo install..."
# Chroot into the new environment (also mounts filesystems).
touch /mnt/gentoo/.gentoo-installer-chroot
arch-chroot /mnt/gentoo
