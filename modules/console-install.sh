#!/bin/bash
# console-install.sh - Gentoo installer module for configuring the system console.
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
# ----------------------------------------------------
# Gentoo Linux Installer Module: Console Configuration
# ----------------------------------------------------
# Configures the system text console using either the traditional
# Linux virtual console or Kmscon.
# ---------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
clear

TMP_CONSOLE=$(mktemp)

dialog --clear \
	--backtitle "Gentoo Linux Installer" \
	--title "Console Type" \
	--menu "Choose which text console to use:" \
	0 0 0 \
	agetty "Traditional Linux virtual console." \
	kmscon "Modern graphical console with improved Unicode support." \
	2>"$TMP_CONSOLE"

CONSOLE_CHOICE=$(<"$TMP_CONSOLE")
rm -f "$TMP_CONSOLE"

info "Selected console: $CONSOLE_CHOICE"
echo
case "$CONSOLE_CHOICE" in
agetty)
	clear
	info "Using the standard Linux virtual console."
	;;

kmscon)
	clear
	status "Installing and configuring Kmscon..."
	echo "sys-apps/kmscon freetype" >/etc/portage/package.use/kmscon
	cat >/etc/portage/package.accept_keywords/kmscon <<EOF
sys-apps/kmscon ~amd64
dev-libs/libtsm ~amd64
EOF
	emerge -qv sys-apps/kmscon
	grep -q '^ERASECHAR[[:space:]]\+0177' /etc/login.defs || sed -Ei 's/^#[[:space:]]*(ERASECHAR[[:space:]]+0177)/\1/' /etc/login.defs
	chmod +x /etc/init.d/kmsconvt
	for n in {1..6}; do
		ln -sf kmsconvt "/etc/init.d/kmsconvt.tty$n"
		rc-update add "kmsconvt.tty$n" default
	done
	cp -v /etc/kmscon/kmscon.conf.example /etc/kmscon/kmscon.conf && chmod go+r /etc/kmscon/kmscon.conf
	sed -Ei \
		-e 's/#switchvt/switchvt/' \
		-e 's/#font-name=Hack Nerd Font/font-name=Hurmit Nerd Font/' \
		-e 's/#hwaccel/hwaccel/' \
		-e 's/#palette=solarized/palette=base16-dark/' \
		/etc/kmscon/kmscon.conf
	;;
esac