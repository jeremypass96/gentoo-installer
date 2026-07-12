#!/bin/bash
# common.sh — Gentoo installer module for providing shared utility functions.
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

# -------------------------------------------------------
# Gentoo Linux Installer Module: Shared Utility Functions
# -------------------------------------------------------
# Shared helper functions used throughout the
# Gentoo Linux Installer.
# -------------------------------------------------------

# Color-coded terminal/console messages.
die() {
	failure "$*"
	exit 1
}

success() {
	echo -e "\e[1;32m>>> $*\e[0m"
}

step() {
	echo -e "\e[1;36m>>> $*\e[0m"
}

status() {
	echo -e "\e[1;38;5;141m>>> $*\e[0m"
}

warning() {
	echo -e "\e[1;33m>>> $*\e[0m"
}

failure() {
	echo -e "\e[1;31mERROR: $*\e[0m" >&2
}

info() {
	echo -e "\e[1;37m>>> $*\e[0m"
}

require_root() {
	if [ "$EUID" -ne 0 ]; then
		die "This script must be run as root."
	fi
}

# Returns 0 if running inside a chroot, 1 otherwise.
# When not chrooted, / and /proc/1/root refer to the same directory.
# Inside a chroot they differ, so -ef returns false.
is_in_chroot() {
	[[ ! / -ef /proc/1/root ]]
}

require_chroot() {
	if ! is_in_chroot; then
		die "This script is intended to be run inside the Gentoo chroot."
	fi
}

require_not_chroot() {
	if is_in_chroot; then
		die "This script must be run outside the chroot (on the live system)."
	fi
}

# Yes/No helper: returns 0 for YES, 1 for NO.
# Usage: if ask_yes_no "Question?" yes; then ...; fi
ask_yes_no() {
	local prompt="$1"
	local default="${2:-yes}"

	if [ "$default" = "yes" ]; then
		dialog --clear --stdout --backtitle "Gentoo Linux Installer" --yesno "$prompt" 0 0
		return $?
	else
		dialog --clear --stdout --defaultno --backtitle "Gentoo Linux Installer" --yesno "$prompt" 0 0
		return $?
	fi
}

# Dialog helpers.
run_step() {
	local msg="$1"
	shift

	"$@" >/dev/null 2>&1 &
	local pid=$!

	while kill -0 "$pid" 2>/dev/null; do
		dialog --backtitle "Gentoo Linux Installer" --infobox "$msg" 3 60
		sleep 0.50
	done

	wait "$pid"
	local status=$?

	if ((status != 0)); then
		pause_msg "Command failed:\n$*"
		exit "$status"
	fi
}

pause_msg() {
	local msg="$1"
	dialog --clear --backtitle "Gentoo Linux Installer" --msgbox "$msg" 0 0
}

# Global USE flag helper.
add_global_use_flag() {
	local flag="$1"

	if ! grep -q -- "$flag" /etc/portage/make.conf; then
		if grep -q '^USE=' /etc/portage/make.conf; then
			sed -i "/^USE=/ s/\"$/ $flag\"/" /etc/portage/make.conf
		else
			echo "USE=\"$flag\"" >>/etc/portage/make.conf
		fi
	fi
}

# Font rendering helper.
configure_font_rendering() {
	eselect fontconfig enable 10-yes-antialias.conf
	eselect fontconfig enable 10-hinting-slight.conf
	eselect fontconfig enable 10-sub-pixel-rgb.conf
	eselect fontconfig enable 11-lcdfilter-default.conf
	eselect fontconfig enable 09-autohint-if-no-hinting.conf
	eselect fontconfig disable 10-autohint.conf
	eselect fontconfig enable 70-no-bitmaps-except-emoji.conf

	fc-cache -fv >/dev/null 2>&1
}

# Verify the downloaded Gentoo stage3 tarball and its signatures.
verify_stage3() {
	sha256sum --check "${STAGE3}.sha256" || return 1
	gpg --import /usr/share/openpgp-keys/gentoo-release.asc || return 1
	gpg --verify "${STAGE3}.asc" || return 1
	gpg --verify "${STAGE3}.DIGESTS" || return 1
	gpg --verify "${STAGE3}.sha256" || return 1
}
