#!/bin/bash
# This script automates the installation of Gentoo Linux with a distribution binary kernel.
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

# Finish chroot'ing into the system.
source /etc/profile
export PS1="(chroot) $PS1"

SCRIPT_DIR="$(cd -- "$(dirname -- "$1")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# Configure portage.
mkdir -p /etc/portage/repos.conf
cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf

# Update the Gentoo ebuild repository
emerge-webrsync

# Select mirrors.
emerge --quiet --verbose --oneshot app-portage/mirrorselect
mirrorselect -i -o >> /etc/portage/make.conf

# Update repository.
emerge --sync

# Install dialog.
if ! command -v dialog >/dev/null 2>&1; then
    echo ">>> Installing dialog for interactive menus..."
    emerge --quiet -qv sys-apps/dialog
fi

# View and set system profile.
bash "$SCRIPT_DIR"/modules/profile-selector.sh

# Run automatic Gentoo CPU optimizations shell script.
bash "$SCRIPT_DIR"/modules/cpu-optimizations.sh

# Configure ACCEPT_LICENSE variable.
cat <<EOF >> /etc/portage/make.conf
# Overrides the profile's ACCEPT_LICENSE default value
ACCEPT_LICENSE="-* @BINARY-REDISTRIBUTABLE @EULA"
EOF

# Configure system settings (e.g., timezone, locale).

# Set timezone.
bash "$SCRIPT_DIR"/modules/timezone-selector.sh

# Configure locale.
bash "$SCRIPT_DIR"/modules/locale-config.sh

# Set the root password using dialog.
while true; do
    rootpass1="$(dialog --stdout --insecure --no-cancel --passwordbox 'Enter root password:' 10 50)"
    rootpass2="$(dialog --stdout --insecure --no-cancel --passwordbox 'Re-enter root password to confirm:' 10 50)"

    if [ "$rootpass1" != "$rootpass2" ]; then
        dialog --title "Error" --msgbox "Root passwords do not match! Please try again." 7 50
        continue
    fi

    if echo -e "$rootpass1\n$rootpass1" | passwd >/dev/null 2>&1; then
        dialog --title "Success" --msgbox "Root password has been set." 7 40
        break
    else
        dialog --title "Error" --msgbox "Failed to set root password! Try again." 7 50
    fi
done


# Add user to the system.
while true; do
    name="$(dialog --stdout --no-cancel --inputbox 'Enter the username for the new account (all lowercase):' 10 50)"

    if [ -z "$name" ]; then
        dialog --title "Error" --msgbox "Username cannot be empty! Please try again." 7 50
        continue
    fi

    if ! printf '%s\n' "$name" | grep -qE '^[a-z][a-z0-9_-]*$'; then
        dialog --title "Error" --msgbox "Username must be lowercase and may contain letters, digits, underscores, or dashes." 9 60
        continue
    fi

    if id "$name" >/dev/null 2>&1; then
        dialog --title "Error" --msgbox "User '$name' already exists! Choose a different name." 7 60
        continue
    fi

    if useradd -m -G users,wheel,audio,cdrom,cdrw,usb,lp,video -s /bin/bash "$name"; then
        dialog --title "Success" --msgbox "User '$name' created successfully." 7 50
        break
    else
        dialog --title "Error" --msgbox "Failed to create user '$name'. Try again." 7 60
    fi
done

# Set the user's password.
while true; do
    userpass1="$(dialog --stdout --insecure --no-cancel --passwordbox "Enter password for user: $name" 10 50)"
    userpass2="$(dialog --stdout --insecure --no-cancel --passwordbox 'Re-enter password to confirm:' 10 50)"

    if [ "$userpass1" != "$userpass2" ]; then
        dialog --title "Error" --msgbox "User passwords do not match! Please try again." 7 60
        continue
    fi

    if echo -e "$userpass1\n$userpass1" | passwd "$name" >/dev/null 2>&1; then
        dialog --title "Success" --msgbox "Password for '$name' has been set." 7 50
        break
    else
        dialog --title "Error" --msgbox "Failed to set password for '$name'. Try again." 7 60
    fi
done

# Configure VIDEO_CARDS variable.
bash "$SCRIPT_DIR"/modules/gpu-autodetect.sh

bash "$SCRIPT_DIR"/pt3.sh
