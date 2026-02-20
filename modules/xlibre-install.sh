#!/bin/bash
# xlibre-install.sh — Gentoo installer module for installing the XLibre Xorg fork.
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

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# Add Xlibre overlay.
eselect repository enable xlibre
emaint sync -r xlibre

# Install Xlibre.
echo "*/*::xlibre ~amd64" > /etc/portage/package.accept_keywords/xlibre
chmod go+r /etc/portage/package.accept_keywords/xlibre
emerge -f x11-base/xlibre-server
emerge -C x11-base/xorg-server
emerge -C x11-base/xorg-drivers
emerge -av1 x11-base/xlibre-server
emerge @x11-module-rebuild
emerge @preserved-rebuild