#!/bin/bash
# create-user.sh - Gentoo installer module for creating a user account.
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
# ------------------------------------------------------
# Gentoo Linux Installer Module: User Account Creation
# ------------------------------------------------------
# Prompts the user for a username, creates the account,
# adds it to the appropriate system groups, and sets the
# account password.
# ------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
clear

# Set the root password using dialog.
while true; do
	rootpass1="$(dialog --stdout --insecure --no-cancel --backtitle "Gentoo Linux Installer" --title "Root Password" --passwordbox 'Enter root password:' 8 40)"
	rootpass2="$(dialog --stdout --insecure --no-cancel --backtitle "Gentoo Linux Installer" --title "Confirm Root Password" --passwordbox 'Re-enter root password to confirm:' 8 40)"

	if [ "$rootpass1" != "$rootpass2" ]; then
		dialog --backtitle "Gentoo Linux Installer" --title "Password Error" --msgbox "Root passwords do not match! \n\nPlease try again." 0 0
		continue
	fi

	if printf '%s\n%s\n' "$rootpass1" "$rootpass1" | passwd >/dev/null 2>&1; then
		dialog --backtitle "Gentoo Linux Installer" --title "Root Password" --msgbox "Root password set successfully." 6 36
		break
	else
		dialog --backtitle "Gentoo Linux Installer" --title "Password Error" --msgbox "Failed to set root password! \n\nPlease try again." 0 0
	fi
done

# Add user to the system.
while true; do
	name="$(dialog --stdout --no-cancel --backtitle "Gentoo Linux Installer" --title "Username" --inputbox 'Enter the username for the new account (lowercase only):' 8 61)"

	if [ -z "$name" ]; then
		dialog --backtitle "Gentoo Linux Installer" --title "Username" --msgbox "Username cannot be empty! \n\nPlease try again." 0 0
		continue
	fi

	if ! printf '%s\n' "$name" | grep -qE '^[a-z][a-z0-9_-]*$'; then
		dialog --backtitle "Gentoo Linux Installer" --title "Username" --msgbox "Username must be lowercase and may contain letters, digits, underscores, or dashes.\n\nPlease try again." 0 0
		continue
	fi

	if id "$name" >/dev/null 2>&1; then
		dialog --backtitle "Gentoo Linux Installer" --title "Username" --msgbox "User '$name' already exists! \n\nChoose a different name." 0 0
		continue
	fi

	if useradd -m -G users,wheel,audio,cdrom,cdrw,usb,lp,video -s /bin/bash "$name"; then
		dialog --backtitle "Gentoo Linux Installer" --title "Create User" --msgbox "User '$name' created successfully.\n\n" 0 0
		break
	else
		dialog --backtitle "Gentoo Linux Installer" --title "Create User" --msgbox "Failed to create user '$name'.\n\nPlease try again." 0 0
	fi
done

# Set the user's password.
while true; do
	userpass1="$(dialog --stdout --insecure --no-cancel --backtitle "Gentoo Linux Installer" --title "User Password" --passwordbox "Enter a password for user '$name':" 0 0)"
	userpass2="$(dialog --stdout --insecure --no-cancel --backtitle "Gentoo Linux Installer" --title "Confirm User Password" --passwordbox 'Re-enter password to confirm:' 8 34)"

	if [ "$userpass1" != "$userpass2" ]; then
		dialog --backtitle "Gentoo Linux Installer" --title "Password Error" --msgbox "User passwords do not match! Please try again.\n\n" 0 0
		continue
	fi

	if printf '%s\n%s\n' "$userpass1" "$userpass1" | passwd "$name" >/dev/null 2>&1; then
		dialog --backtitle "Gentoo Linux Installer" --title "User Password" --msgbox "Password for '$name' set successfully.\n\n" 0 0
		break
	else
		dialog --backtitle "Gentoo Linux Installer" --title "Password Error" --msgbox "Failed to set password for '$name'.\n\nPlease try again." 0 0
	fi
done