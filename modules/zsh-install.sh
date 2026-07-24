#!/bin/bash
# zsh-install.sh - Gentoo installer module for installing and configuring Zsh.
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
# -----------------------------------------------
# Gentoo Linux Installer Module: Zsh Installation
# -----------------------------------------------
# Installs Zsh, Oh My Zsh, plugins, themes, shell
# configuration, command suggestion support, and
# additional shell enhancements.
# -----------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
clear

# --------------------------
# Install Zsh and Oh My Zsh.
# --------------------------
status "Installing and configuring Zsh..."
emerge -qv app-shells/zsh app-shells/gentoo-zsh-completions
eselect repository enable guru
emerge --sync guru
emerge -aqv app-shells/ohmyzsh
cp -v /usr/share/zsh/site-contrib/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc
sed -i 's|ZSH="$HOME/.oh-my-zsh"|ZSH="/usr/share/zsh/site-contrib/oh-my-zsh"|' /etc/skel/.zshrc
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="jpassarelli"/' /etc/skel/.zshrc
sed -i 's/# HYPHEN_INSENSITIVE="true"/HYPHEN_INSENSITIVE="true"/' /etc/skel/.zshrc
sed -i "s/^# zstyle ':omz:update' mode disabled/zstyle ':omz:update' mode disabled/" /etc/skel/.zshrc
sed -i 's/# ENABLE_CORRECTION="true"/ENABLE_CORRECTION="true"/' /etc/skel/.zshrc
sed -i 's/# COMPLETION_WAITING_DOTS="true"/COMPLETION_WAITING_DOTS="true"/' /etc/skel/.zshrc
sed -i 's/# DISABLE_UNTRACKED_FILES_DIRTY="true"/DISABLE_UNTRACKED_FILES_DIRTY="true"/' /etc/skel/.zshrc
sed -i 's|# HIST_STAMPS="mm/dd/yyyy"|HIST_STAMPS="mm/dd/yyyy"|' /etc/skel/.zshrc
sed -i 's/plugins=(git)/plugins=(git extract safe-paste sudo copypath zsh-autosuggestions zsh-syntax-highlighting)/' /etc/skel/.zshrc
ZSH_CUSTOM=/usr/share/zsh/site-contrib/oh-my-zsh/custom
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
wcurl --curl-options="--progress-bar" -o ${ZSH_CUSTOM}/themes/jpassarelli.zsh-theme https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/jpassarelli.zsh-theme

# -----------------------------
# Configure the default .zshrc.
# -----------------------------
status "Configuring the Zsh environment..."
cat <<EOF >>/etc/skel/.zshrc
# Set the default umask.
umask 022

# Disable highlighting of pasted text.
zle_highlight=('paste:none')

# Apply sensible history settings.
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS

# Make some sensible aliases.
alias ls="lsd"
alias cat="bat"
alias emerge-autoremove="sudo emerge -ac"
alias update-world="sudo emerge -auvqDN @world"
alias update-system="sudo emerge -auvqDN @world"
alias wcurl='wcurl --curl-options="--progress-bar"'
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"

# Run fastfetch.
fastfetch

# Enable Gentoo autocompletion.
autoload -U compinit
compinit
zstyle ':completion::complete:*' use-cache 1

# Enable command-not-found.
source /etc/bash/bashrc.d/command-not-found.sh
EOF

# -------------------------
# Configure the user shell.
# -------------------------
status "Applying Zsh configuration..."
cp -v /etc/skel/.zshrc /home/"$name"/.zshrc
chown "$name":"$name" /home/"$name"/.zshrc

# -------------------------
# Configure the root shell.
# -------------------------
cp -v /etc/skel/.zshrc /root/.zshrc
sed -i 's/emerge-autoremove="sudo emerge -ac"/emerge-autoremove="emerge -ac"/' /root/.zshrc
sed -i 's/update-world="sudo emerge -auvqDN @world"/update-world="emerge -auvqDN @world"/' /root/.zshrc
sed -i 's/update-system="sudo emerge -auvqDN @world"/update-system="emerge -auvqDN @world"/' /root/.zshrc
sed -i 's|update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"|update-grub="grub-mkconfig -o /boot/grub/grub.cfg"|' /root/.zshrc
sed -i '/^# Run fastfetch\.$/,/^$/d' /root/.zshrc

# -----------------------------------
# Install command suggestion support.
# -----------------------------------
status "Installing command suggestion support..."
# Configure Portage for command suggestion support.
echo "sys-apps/util-linux caps" >/etc/portage/package.use/pfl
chmod go+r /etc/portage/package.use/pfl
# Install command suggestion packages.
emerge -qv app-portage/command-not-found app-portage/pfl

# ----------------------
# Install BOFH fortunes.
# ----------------------
status "Installing humorous system administrator excuses..."
emerge -qv games-misc/fortune-mod-bofh-excuses
cat >>/root/.zshrc <<'EOF'

# Fun BOFH excuses, because why not!
fortune bofh-excuses | cowsay -f tux
EOF
