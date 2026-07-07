#!/bin/bash
# posy-cursors-install.sh - script to install Posy's cursors on Gentoo, since only the AUR from Arch Linux has them.
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

# -------------------------------------------
# Gentoo Linux Installer Module: Posy Cursors
# -------------------------------------------
# Provides:
# - Downloads the Posy cursor themes.
# - Installs the cursor themes system-wide.
# - Sets the correct file permissions.
# - Removes temporary installation files.
# -------------------------------------------

echo ">>> Installing Posy cursors..."
echo ">>> Cloning Posy cursors GitHub repo..."
git -C "$HOME" clone https://github.com/Icelk/posy-cursors.git

echo ">>> Copying cursors to /usr/share/icons..."
cp -rp "$HOME"/posy-cursors/themes/posy-white /usr/share/icons/posy-cursors
cp -rp "$HOME"/posy-cursors/themes/posy-black /usr/share/icons/posy-cursors-black

echo ">>> Applying correct user permissions..."
chown -R root:root /usr/share/icons/posy-cursors /usr/share/icons/posy-cursors-black
find /usr/share/icons/posy-cursors /usr/share/icons/posy-cursors-black -type d -exec chmod 755 {} \;
find /usr/share/icons/posy-cursors /usr/share/icons/posy-cursors-black -type f -exec chmod 644 {} \;

echo ">>> Removing temporary repository clone from root's home directory..."
cd && rm -rf "$HOME"/posy-cursors

echo ">>> Done. Posy cursors are now installed."
