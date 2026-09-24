#!/bin/bash
#!/bin/bash
# helix-install.sh - Gentoo installer module for installing the Helix editor.
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
# --------------------------------------------------------
# Gentoo Linux Installer Module: Helix Editor Installation
# ------------------------------------------------------
# Installs the Helix text editor, configures system-wide
# defaults, and installs Homebrew along with Taplo
# for TOML formatting support, shfmt for shell
# script formatting support, and dprint for Markdown
# formatting support.
# ------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
screen

# --------------
# Install Helix.
# --------------
status "Installing the Helix text editor..."
emerge -qv app-editors/helix

# ----------------
# Configure Helix.
# ----------------
status "Configuring the Helix text editor..."
mkdir -p /etc/skel/.config/helix
wcurl --curl-options="--progress-bar" -o /etc/skel/.config/helix/config.toml https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/Dotfiles/config/helix/config.toml
wcurl --curl-options="--progress-bar" -o /etc/skel/.config/helix/languages.toml https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/Dotfiles/config/helix/languages.toml
mkdir -p /home/"$name"/.config/helix
cp -v /etc/skel/.config/helix/config.toml /home/"$name"/.config/helix/config.toml
cp -v /etc/skel/.config/helix/languages.toml /home/"$name"/.config/helix/languages.toml
chmod go+r /home/"$name"/.config/helix/*.toml
chown -R "$name":"$name" /home/"$name"/.config/helix
mkdir -p /root/.config/helix
cp -v /etc/skel/.config/helix/config.toml /root/.config/helix/config.toml
cp -v /etc/skel/.config/helix/languages.toml /root/.config/helix/languages.toml

# -------------------------------------------------
# Install Helix Markdown formatter/language-server.
# -------------------------------------------------
emerge -qv dev-util/marksman

# -------------------------------------------------------
# Install Homebrew (needed for toplo, shfmt, and dprint).
# -------------------------------------------------------
mkdir -p /home/linuxbrew/.linuxbrew
chown -R "$name:$name" /home/linuxbrew/.linuxbrew
if su - "$name" -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
	for zshrc in /root/.zshrc /home/"$name"/.zshrc /etc/skel/.zshrc; do
		cat >>"$zshrc" <<'EOF'

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
EOF
	done
	su - "$name" -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)" && brew install --no-ask taplo shfmt dprint'
fi
