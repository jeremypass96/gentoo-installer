#!/bin/bash
# nerd-fonts-config.sh - Gentoo installer module for configuring Nerd Fonts.
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
# -------------------------------------------------------
# Gentoo Linux Installer Module: Nerd Fonts Configuration
# -------------------------------------------------------
# Enables the required overlay, keyword, and license entries
# needed to install the Nerd Fonts package.
# ----------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot

# Configure Portage for nerd fonts.
eselect repository enable xarblu-overlay
emerge --sync xarblu-overlay
echo "media-fonts/nerd-fonts" >/etc/portage/package.accept_keywords/nerd-fonts
chmod go+r /etc/portage/package.accept_keywords/nerd-fonts
echo "media-fonts/nerd-fonts Vic-Fieger-License" >>/etc/portage/package.license
chmod go+r /etc/portage/package.license
