#!/bin/bash
# hardware-notify.sh - Gentoo installer module for installing a Windows-style hardware desktop notification script.
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

# -------------------------------------------------------------
# Gentoo Linux Installer Module: Hardware Notifications
# -------------------------------------------------------------
# Provides:
# - Installs a Windows-style hardware notification service.
# - Automatically starts the notification service on login.
# - Displays desktop notifications for newly connected devices.
# -------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# Create the 'hardware-notify' script.
cat <<'EOF' >/usr/local/bin/hardware-notify
#!/usr/bin/bash
# Windows-style hardware notifications for Linux desktops.

SEEN_FILE="$HOME/.local/share/hardware-notify/seen-devices"
mkdir -p "$(dirname "$SEEN_FILE")"
touch "$SEEN_FILE"

udevadm monitor --udev --property |
	awk '
BEGIN { RS=""; FS="\n" }
/^UDEV.*add/ && (/DEVTYPE=usb_device/ || /DEVTYPE=disk/ || /ID_INPUT_MOUSE=1/ || /ID_INPUT_KEYBOARD=1/ || /ID_INPUT_JOYSTICK=1/ || /SUBSYSTEM=sound/ || /SUBSYSTEM=video4linux/ || /SUBSYSTEM=printer/ || /SUBSYSTEM=bluetooth/) {
    name="Hardware device"
    vendor_name=""
    vendor=""
    model=""
    serial=""

for (i=1; i<=NF; i++) {

    if ($i ~ /^ID_VENDOR_FROM_DATABASE=/)
        vendor_name = substr($i, 25)
    else if ($i ~ /^ID_VENDOR=/ && vendor_name == "")
        vendor_name = substr($i, 11)

    if ($i ~ /^ID_MODEL_FROM_DATABASE=/)
        name = substr($i, 24)
    else if ($i ~ /^ID_MODEL=/ && name == "Hardware device") {
        name = substr($i, 10)
        gsub("_", " ", name)
    }

    if ($i ~ /^ID_VENDOR_ID=/)
        vendor = substr($i, 14)

    if ($i ~ /^ID_MODEL_ID=/)
        model = substr($i, 13)

    if ($i ~ /^ID_SERIAL_SHORT=/)
        serial = substr($i, 17)
}

    gsub(/ Corp\.$/, "", vendor_name)
    gsub(/ Corporation$/, "", vendor_name)
    gsub(/ Inc\.$/, "", vendor_name)
    gsub(/,? Inc\.$/, "", vendor_name)
    gsub(/ Ltd\.$/, "", vendor_name)

    if (vendor_name != "")
        name = vendor_name " " name

    id=vendor ":" model ":" serial

    print id "\t" name
    fflush()
}
' |
	while IFS=$'\t' read -r device_id device_name; do
		[[ -z "$device_id" ]] && continue

		if ! grep -Fxq "$device_id" "$SEEN_FILE"; then
			notify-send --icon=computer "Found New Hardware" "$device_name"

			echo "$device_id" >>"$SEEN_FILE"
		fi
	done
EOF

# Set script user permissions.
chmod 755 /usr/local/bin/hardware-notify

# Create desktop file entry.
mkdir -p /home/"$name"/.config/autostart
cat <<EOF >/home/"$name"/.config/autostart/hardware-notify.desktop
[Desktop Entry]
Type=Application
Name=Hardware Notify
Comment=Show notifications when new hardware is connected
Exec=hardware-notify
Terminal=false
EOF
chown "$name:$name" "/home/$name/.config/autostart/hardware-notify.desktop"
