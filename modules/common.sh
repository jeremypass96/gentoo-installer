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

die() {
	echo "ERROR: $*" >&2
	exit 1
}

require_root() {
	if [ "$EUID" -ne 0 ]; then
		die "This script must be run as root."
	fi
}

# Returns 0 if in chroot, 1 if not.
is_in_chroot() {
	[ -f "/.gentoo-installer-chroot" ]
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
	local ans

	if command -v dialog >/dev/null 2>&1; then
		if [ "$default" = "yes" ]; then
			dialog --clear --stdout --backtitle "Gentoo Linux Installer" --yesno "$prompt" 0 0
			return $?
		else
			dialog --clear --stdout --defaultno --backtitle "Gentoo Linux Installer" --yesno "$prompt" 0 0
			return $?
		fi
	else
		while true; do
			read -r -p "$prompt [y/n] (default: $default): " ans
			ans="${ans,,}" # lowercase
			case "$ans" in
			y | yes) return 0 ;;
			n | no) return 1 ;;
			"")
				if [ "$default" = "yes" ]; then
					return 0
				else
					return 1
				fi
				;;
			*) echo "Please answer y or n." ;;
			esac
		done
	fi
}

# Dialog helpers.
run_step() {
	local msg="$1"
	shift

	if command -v dialog >/dev/null 2>&1; then
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
	else
		echo ">>> $msg"
		"$@" || {
			local status=$?
			echo "Command failed:"
			echo "  $*"
			exit $status
		}
	fi
}

pause_msg() {
	local msg="$1"
	if command -v dialog >/dev/null 2>&1; then
		dialog --clear --backtitle "Gentoo Linux Installer" --msgbox "$msg" 10 34
	else
		echo "$msg"
		read -r -p "Press Enter to continue..."
	fi
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

	fc-cache -fv
}
