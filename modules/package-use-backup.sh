#!/bin/bash
# package-use-backup.sh - Gentoo installer module for backing up package.use files.
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
# -------------------------------------------------
# Gentoo Linux Installer Module: package.use Backup
# -------------------------------------------------
# Creates backups of existing package.use configuration files
# before the installer modifies them.
# -----------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot

# ------------------------------
# Failsafe for USE flag changes.
# ------------------------------
USE_FILES=(
	qttools
	sudo
	vscodium
	vlc
	audacity
	portaudio
	pipewire
	avahi
	man-db
	manpager
	installkernel
	module-rebuild
	grub
	networkmanager
	cups
	hplip
	kde
	xfce
	mate
	cinnamon
	lightdm
)

BACKUP_DIR="/etc/portage/package.use/.install-backup.$(date +%s)"
mkdir -p "${BACKUP_DIR}"

# Backup existing files (if they exist).
for f in "${USE_FILES[@]}"; do
	if [[ -f "/etc/portage/package.use/${f}" ]]; then
		cp "/etc/portage/package.use/${f}" "${BACKUP_DIR}/${f}"
	fi
done
