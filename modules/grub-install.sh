#!/bin/bash
# grub-install.sh - Gentoo installer module for installing the GRUB bootloader.
# Copyright (C) 2026 Jeremy Passarelli <recordguy96@aol.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# -----------------------------------------------------------
# Gentoo Linux Installer Module: GRUB Bootloader Installation
# -----------------------------------------------------------
# Installs and configures the GRUB bootloader, optionally
# enables the Plymouth graphical boot splash, and installs
# GRUB for either UEFI or legacy BIOS systems.
# --------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
clear

# -------------
# Install GRUB.
# -------------
status "Installing and configuring GRUB..."
emerge -qv sys-boot/grub

# ---------------
# Configure GRUB.
# ---------------
sed -i 's|^#GRUB_CMDLINE_LINUX=".*"|GRUB_CMDLINE_LINUX="nowatchdog nmi_watchdog=0 net.ifnames=0"|' /etc/default/grub

# ----------------------------
# Install Plymouth (optional).
# ----------------------------
if ask_yes_no "Install the Plymouth graphical boot splash?" yes; then
	echo "sys-boot/plymouth-openrc-plugin ~amd64" >/etc/portage/package.accept_keywords/plymouth-openrc-plugin
	chmod go+r /etc/portage/package.accept_keywords/plymouth-openrc-plugin
	emerge -qv sys-boot/plymouth sys-boot/plymouth-openrc-plugin
	sed -i 's|^#GRUB_CMDLINE_LINUX_DEFAULT=".*"|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|' /etc/default/grub
	bash "$SCRIPT_DIR"/modules/plymouth-theme-install.sh
fi

# -----------------------------------
# Install GRUB for the target system.
# -----------------------------------
# Get the block device backing /.
ROOT_DEV=$(findmnt -no SOURCE /)
# Get the parent disk (e.g. sda from sda2, or nvme0n1 from nvme0n1p2).
DISK_NAME=$(lsblk -no PKNAME "$ROOT_DEV")
DRIVE="/dev/${DISK_NAME}"
if [[ -d /sys/firmware/efi ]]; then
	status "UEFI detected — installing GRUB for EFI..."
	mountpoint -q /boot || mount "${DRIVE}1" /boot
	mkdir -p /boot/EFI
	grub-install --efi-directory=/boot --bootloader-id=Gentoo
	echo "GRUB_CFG=/boot/EFI/Gentoo/grub.cfg" >/etc/env.d/99grub
	env-update
	GRUB_CFG=/boot/EFI/Gentoo/grub.cfg
else
	status "BIOS detected — installing GRUB for BIOS on $DRIVE..."
	grub-install "$DRIVE"
	GRUB_CFG=/boot/grub/grub.cfg
fi

grub-mkconfig -o "$GRUB_CFG"
success "GRUB installed successfully."
success "Installation complete! Reboot and enjoy your new Gentoo system!"
