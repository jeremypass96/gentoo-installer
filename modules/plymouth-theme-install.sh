#!/bin/bash
# plymouth-theme-install.sh - script to install a decent Gentoo Plymouth theme.
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

# ---------------------------------------------
# Gentoo Linux Installer Module: Plymouth Theme
# ---------------------------------------------
# Provides:
# - Downloads the Gentoo Plymouth theme.
# - Installs the theme system-wide.
# - Sets it as the default Plymouth theme.
# ---------------------------------------------

echo ">>> Cloning Plymouth theme repo..."
git -C "$HOME" clone https://gitlab.com/menelkir/plymouth-theme-gentoo-logo-new.git

echo ">>> Making theme directory..."
mkdir /usr/share/plymouth/themes/gentoo-logo-new

echo ">>> Copying theme to /usr/share/plymouth/themes/..."
cp -rv "$HOME"/plymouth-theme-gentoo-logo-new/* /usr/share/plymouth/themes/gentoo-logo-new
rm /usr/share/plymouth/themes/gentoo-logo-new/README.rst

echo ">>> Removing GitHub repo directory from user's home directory..."
rm -rf "$HOME"/plymouth-theme-gentoo-logo-new

echo ">>> Applying theme..."
plymouth-set-default-theme -R gentoo-logo-new