#!/bin/bash
# browser-install.sh - Gentoo installer module for installing a web browser.
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
# -------------------------------------------------------
# Gentoo Linux Installer Module: Web Browser Installation
# -------------------------------------------------------
# Installs the user's selected web browser and performs any
# required repository or package configuration.
# ---------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot

TMP_BROWSER=$(mktemp)
dialog --clear \
	--backtitle "Gentoo Linux Installer" \
	--no-cancel \
	--title "Web Browser" \
	--menu "Choose a web browser to install:" \
	0 0 0 \
	brave "Brave (Privacy-based browser with ad-blocking, fingerprinting protection, etc.)" \
	chromium "Chromium (Open-source version of Google Chrome.)" \
	vivaldi "Vivaldi" \
	ungchromium "Ungoogled Chromium" \
	cromite "Similar to Brave. A fork of the Bromite Android browser that runs on PCs." \
	helium "Similar to Brave, but with no cloud-based data sync or password manager." \
	none "No web browser." \
	2>"$TMP_BROWSER"
BROWSER_CHOICE=$(<"$TMP_BROWSER")

rm -f "$TMP_BROWSER"

INSTALL_BRAVE=false
INSTALL_CHROMIUM=false
INSTALL_VIVALDI=false
INSTALL_UNG_CHROMIUM=false
INSTALL_CROMITE=false
INSTALL_HELIUM=false

case "$BROWSER_CHOICE" in
brave) INSTALL_BRAVE=true ;;
chromium) INSTALL_CHROMIUM=true ;;
vivaldi) INSTALL_VIVALDI=true ;;
ungchromium) INSTALL_UNG_CHROMIUM=true ;;
cromite) INSTALL_CROMITE=true ;;
helium) INSTALL_HELIUM=true ;;
none | *) ;;
esac

if [ "$INSTALL_BRAVE" = true ]; then
	eselect repository enable another-brave-overlay
	emerge --sync another-brave-overlay
	emerge -qv www-client/brave-browser
	rm -f /usr/share/applications/com.brave.Browser.desktop
fi

if [ "$INSTALL_CHROMIUM" = true ]; then
	emerge -qv www-client/chromium
fi

if [ "$INSTALL_VIVALDI" = true ]; then
	emerge -qv www-client/vivaldi
fi

if [ "$INSTALL_UNG_CHROMIUM" = true ]; then
	eselect repository enable pf4public
	emerge --sync pf4public
	emerge -qv www-client/ungoogled-chromium-bin
fi

if [ "$INSTALL_CROMITE" = true ]; then
	eselect repository enable pf4public
	emerge --sync pf4public
	echo "www-client/cromite-bin ~amd64" >/etc/portage/package.accept_keywords/cromite-bin
	chmod go+r /etc/portage/package.accept_keywords/cromite-bin
	emerge -qv www-client/cromite-bin
fi

if [ "$INSTALL_HELIUM" = true ]; then
	eselect repository enable guru
	emerge --sync guru
	echo "www-client/helium-bin ~amd64" >/etc/portage/package.accept_keywords/helium-bin
	chmod go+r /etc/portage/package.accept_keywords/helium-bin
	emerge -qv www-client/helium-bin
fi

if [ "$BROWSER_CHOICE" = "none" ]; then
	status "Continuing without a graphical web browser..."
fi