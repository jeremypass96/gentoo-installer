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

run_step "Downloading Plymouth theme..." \
	git -C "$HOME" clone https://github.com/Schroedingersdoraemon/vortex-gentoo

run_step "Creating theme directory..." \
	mkdir /usr/share/plymouth/themes/vortex-gentoo

run_step "Copying theme to /usr/share/plymouth/themes/..." \
	cp -r "$HOME"/vortex-gentoo/* /usr/share/plymouth/themes/vortex-gentoo

# Remove unneeded pointless files.
rm /usr/share/plymouth/themes/vortex-gentoo/README.md && rm /usr/share/plymouth/themes/vortex-gentoo/screenshot.png

run_step "Cleaning up temporary files..." \
	rm -rf "$HOME"/vortex-gentoo

run_step "Applying theme..." \
	plymouth-set-default-theme -R vortex-gentoo >/dev/null 2>&1
