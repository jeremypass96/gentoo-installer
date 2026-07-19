#!/bin/bash
# kernel-install.sh - Gentoo installer module for installing the Linux kernel.
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
# --------------------------------------------------------
# Gentoo Linux Installer Module: Linux Kernel Installation
# --------------------------------------------------------
# Installs the selected Linux kernel package.
# -------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot

TMP_KERNEL=$(mktemp)

dialog --clear \
	--backtitle "Gentoo Linux Installer" \
	--title "Kernel Selection" \
	--menu "Choose which Linux kernel to install:" \
	0 0 0 \
	bin "Gentoo Binary Kernel (gentoo-kernel-bin) - Fast, easy, works for everyone." \
	src "Gentoo Source Kernel (gentoo-kernel) - For custom configs via menuconfig." \
	2>"$TMP_KERNEL"

KERNEL_CHOICE=$(<"$TMP_KERNEL")
rm -f "$TMP_KERNEL"

case "$KERNEL_CHOICE" in
bin)
	clear
	status "Installing Gentoo binary kernel..."
	emerge -qv sys-kernel/gentoo-kernel-bin
	;;

src)
	clear
	status "Installing Gentoo source kernel..."
	emerge -qv sys-kernel/gentoo-kernel
	;;
esac