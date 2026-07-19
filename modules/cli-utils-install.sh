#!/bin/bash
# cli-tools-install.sh - Gentoo installer module for installing command-line utilities.
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
# -----------------------------------------------------
# Gentoo Linux Installer Module: Command-Line Utilities
# ------------------------------------------------------
# Installs and configures command-line utilities such as
# bat, Fastfetch, and LSD, along with their system-wide
# configuration files.
# ------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
clear

status "Installing and configuring command-line utilities..."
# --------------------------
# Configure Portage for bat.
# --------------------------
echo "sys-apps/bat ~amd64" >/etc/portage/package.accept_keywords/bat
chmod go+r /etc/portage/package.accept_keywords/bat

# --------------------------------------
# Install command-line utility packages.
# --------------------------------------
emerge -qv sys-apps/bat app-misc/fastfetch sys-apps/lsd

# --------------------------------------------------------
# Configure bat (cat clone with color, line numbers, etc.)
# --------------------------------------------------------
wcurl --curl-options="--progress-bar" -o /etc/bat/config https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/Dotfiles/config/bat/config
chmod go+r /etc/bat/config
echo 'BAT_CONFIG_PATH="/etc/bat"' >>/etc/env.d/99bat && env-update
chmod go+r /etc/env.d/99bat
mkdir -p /etc/bat/themes
wget -P /etc/bat/themes https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme
chmod 755 /etc/bat/themes
chmod go+r /etc/bat/themes/Catppuccin\ Mocha.tmTheme
bat cache --build

# --------------------
# Configure Fastfetch.
# --------------------
mkdir -p /etc/skel/.config/fastfetch
wcurl --curl-options="--progress-bar" -o /etc/skel/.config/fastfetch/config.jsonc https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/Dotfiles/config/fastfetch/config.jsonc
mkdir -p /home/"$name"/.config/fastfetch && cp -v /etc/skel/.config/fastfetch/config.jsonc /home/"$name"/.config/fastfetch
chmod go+r /etc/skel/.config/fastfetch/config.jsonc
chown -R "$name":"$name" /home/"$name"/.config/fastfetch
chmod go+r /home/"$name"/.config/fastfetch/config.jsonc
mkdir -p ~/.config/fastfetch && cp -v /etc/skel/.config/fastfetch/config.jsonc ~/.config/fastfetch/

# -------------------------
# Configure LSD (LSDeluxe).
# -------------------------
mkdir -p /etc/skel/.config/lsd
wcurl --curl-options="--progress-bar" -o /etc/skel/.config/lsd/config.yaml https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/Dotfiles/config/lsd/config.yaml
mkdir -p /home/"$name"/.config/lsd && cp -v /etc/skel/.config/lsd/config.yaml /home/"$name"/.config/lsd
chmod go+r /etc/skel/.config/lsd/config.yaml
chown -R "$name":"$name" /home/"$name"/.config/lsd
chmod go+r /home/"$name"/.config/lsd/config.yaml
mkdir -p ~/.config/lsd && cp -v /etc/skel/.config/lsd/config.yaml ~/.config/lsd
