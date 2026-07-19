#!/bin/bash
# hostname.sh - Gentoo installer module for configuring the system hostname.
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# -----------------------------------------------------
# Gentoo Linux Installer Module: Hostname Configuration
# -----------------------------------------------------
# Prompts the user for a system hostname and writes the
# appropriate Gentoo configuration files.
# -----------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
clear

DEFAULT_HOSTNAME="GentooBox"
HOSTNAME=$(
	dialog --clear \
		--no-cancel \
		--backtitle "Gentoo Linux Installer" \
		--title "System Hostname" \
		--inputbox "Enter a hostname for this system:" 8 38 "$DEFAULT_HOSTNAME" \
		3>&1 1>&2 2>&3
)
clear
[ -z "$HOSTNAME" ] && HOSTNAME="$DEFAULT_HOSTNAME"
dialog --clear \
	--backtitle "Gentoo Linux Installer" \
	--title "Hostname Set" \
	--msgbox "The system hostname has been set to:\n\n$HOSTNAME" 7 41
HOSTNAME=${HOSTNAME:-GentooBox}
echo "$HOSTNAME" >/etc/hostname
sed -i 's/^hostname=.*/hostname="'"$HOSTNAME"'"/' /etc/conf.d/hostname