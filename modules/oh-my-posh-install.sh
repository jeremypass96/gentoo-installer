#!/bin/bash
# oh-my-posh-install.sh - Gentoo installer module for installing and configuring Oh My Posh.
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
# ------------------------------------------------------
# Gentoo Linux Installer Module: Oh My Posh Installation
# ------------------------------------------------------
# Installs and configures Oh My Posh and its prompt
# configuration.
# ------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
screen

# -------------------
# Install Oh My Posh.
# -------------------
status "Installing and configuring Oh My Posh..."
# shellcheck disable=SC2016
# shellcheck disable=SC2154
su - "$name" -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)" && brew install --no-ask oh-my-posh'
mkdir -p /home/"$name"/.config/ohmyposh
mkdir -p /etc/skel/.config/ohmyposh
mkdir -p /root/.config/ohmyposh
wcurl --curl-options "--progress-bar" -o /etc/skel/.config/ohmyposh/jpassarelli.omp.json https://gist.githubusercontent.com/jeremypass96/1a1d5a63518e063f8446785376d4adbd/raw/b3d5fe68d2acddcf22dac57defc64605c1fae1ba/jpassarelli.omp.json
cp /etc/skel/.config/ohmyposh/jpassarelli.omp.json /home/"$name"/.config/ohmyposh/jpassarelli.omp.json
cp /etc/skel/.config/ohmyposh/jpassarelli.omp.json /root/.config/ohmyposh/jpassarelli.omp.json
chown -R "$name:$name" /home/"$name"/.config/ohmyposh
