#!/bin/bash
# desktop-selector.sh - Gentoo installer module for selecting a desktop environment.
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
# ------------------------------------------------------------
# Gentoo Linux Installer Module: Desktop Environment Selection
# ------------------------------------------------------------
# Presents a list of supported desktop environments and configures
# the system to install the selected desktop environment.
# ----------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
clear

TMP_DESKTOP=$(mktemp)
dialog --clear \
	--backtitle "Gentoo Linux Installer" \
	--title "Desktop Environment" \
	--menu "Choose a desktop environment to install:" \
	0 0 0 \
	plasma "KDE Plasma" \
	xfce "Xfce" \
	mate "MATE" \
	cinnamon "Cinnamon" \
	tde "Trinity Desktop Environment (fork of KDE 3)" \
	none "No desktop (CLI-only, or you'll configure it later yourself.)" \
	2>"$TMP_DESKTOP"

if [ $? -ne 0 ]; then
	DESKTOP="none"
else
	DESKTOP=$(<"$TMP_DESKTOP")
fi
rm -f "$TMP_DESKTOP"

INSTALL_PLASMA=false
INSTALL_XFCE=false
INSTALL_MATE=false
INSTALL_CINNAMON=false
INSTALL_TDE=false

case "$DESKTOP" in
plasma) INSTALL_PLASMA=true ;;
xfce) INSTALL_XFCE=true ;;
mate) INSTALL_MATE=true ;;
cinnamon) INSTALL_CINNAMON=true ;;
tde) INSTALL_TDE=true ;;
none | *) ;;
esac