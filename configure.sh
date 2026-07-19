#!/bin/bash
# This installer automates the installation of Gentoo Linux.
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

# Finish chroot'ing into the system.
source /etc/profile
export PS1="(chroot) $PS1"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# Configure portage.
mkdir -p /etc/portage/repos.conf
cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf

# Update the Gentoo ebuild repository
emerge-webrsync

# Select mirrors.
emerge -qv1 app-portage/mirrorselect
mirrorselect -i -o >>/etc/portage/make.conf

# Update repository.
emerge --sync

# Ensure dialog is available.
if ! command -v dialog >/dev/null 2>&1; then
	status "Installing required package: dialog..."
	emerge -q dev-util/dialog
fi

# View and set system profile.
bash "$SCRIPT_DIR"/modules/profile-selector.sh

# Run automatic Gentoo CPU optimizations shell script.
bash "$SCRIPT_DIR"/modules/cpu-optimizations.sh

# Configure ACCEPT_LICENSE variable.
cat <<EOF >>/etc/portage/make.conf
# Overrides the profile's ACCEPT_LICENSE default value
ACCEPT_LICENSE="-* @BINARY-REDISTRIBUTABLE @EULA"
EOF

# Configure system settings (e.g., timezone, locale).

# Set timezone.
bash "$SCRIPT_DIR"/modules/timezone-selector.sh

# Configure locale.
bash "$SCRIPT_DIR"/modules/locale-config.sh

# Add user to the system.
bash "$SCRIPT_DIR"/modules/create-user.sh

# Configure VIDEO_CARDS variable.
status "Detecting graphics hardware..."
bash "$SCRIPT_DIR"/modules/gpu-autodetect.sh

# Set hostname.
bash "$SCRIPT_DIR"/modules/hostname.sh

# Select a desktop environment.
source "$SCRIPT_DIR"/modules/desktop-selector.sh

# Backup existing package.use files.
bash "$SCRIPT_DIR"/modules/package-use-backup.sh

# Configure USE flags.
source "$SCRIPT_DIR"/modules/package-use.sh

# ---------------------------------
# Update system with new USE flags.
# ---------------------------------
if ! emerge -avquDN @world; then
	echo
	failure "@world update FAILED! Restoring previous USE flag files..."
	for f in "${USE_FILES[@]}"; do
		if [[ -f "${BACKUP_DIR}/${f}" ]]; then
			mv "${BACKUP_DIR}/${f}" "/etc/portage/package.use/${f}"
		else
			rm -f "/etc/portage/package.use/${f}"
		fi
	done
	success "Previous USE flag files restored."
	warning "Fix the problem and rerun this step manually."
	exit 1
else
	rm -rf "${BACKUP_DIR}"
fi

# Clean up any orphaned/unneeded dependencies.
status "Removing orphaned dependencies..."
emerge -cq
status "Rebuilding packages using preserved libraries..."
emerge @preserved-rebuild
success "System cleanup complete."

# Install selected desktop environment.
source "$SCRIPT_DIR/modules/desktop-install.sh"

# Install a better manpager.
clear
status "Installing an enhanced man page viewer..."
echo "app-shells/manpager ~amd64" >/etc/portage/package.accept_keywords/manpager
chmod go+r /etc/portage/package.accept_keywords/manpager
emerge -qv app-shells/manpager

# Install some nice Gentoo-specific scripts.
clear
status "Installing Gentoolkit..."
emerge -qv app-portage/gentoolkit

# Install Linux firmware.
clear
status "Installing Linux firmware..."
emerge -qv sys-kernel/linux-firmware

# Configure dracut.
mkdir -p /etc/dracut.conf.d
echo 'kernel_cmdline+=" nowatchdog nmi_watchdog=0 net.ifnames=0 "' >/etc/dracut.conf.d/kernel.conf
# Generate initramfs.
run_step "Generating initramfs..." \
	dracut -f >/dev/null 2>&1
success "Initramfs successfully generated!"

# Install sys-kernel/installkernel.
clear
status "Installing kernel management tools..."
emerge -qv sys-kernel/installkernel

# Update environment variables.
env-update >/dev/null 2>&1

# Install kernel.
bash "$SCRIPT_DIR"/modules/kernel-install.sh

# Install and enable NetworkManager.
clear
status "Installing NetworkManager..."
emerge -qv net-misc/networkmanager
rc-update add NetworkManager default

# Fix /etc/hosts.
if grep -q '^127\.0\.0\.1' /etc/hosts; then
	sed -i 's/^127\.0\.0\.1.*/127.0.0.1   '"$HOSTNAME"'/' /etc/hosts
else
	echo '127.0.0.1   '"$HOSTNAME"'' >>/etc/hosts
fi

# Install system logger.
clear
status "Installing system logger..."
emerge -qv app-admin/sysklogd
rc-update add sysklogd default

# Install cron daemon.
clear
status "Installing cron daemon..."
emerge -qv sys-process/cronie
rc-update add cronie default

# Install file indexing utility.
clear
status "Installing file indexing utility..."
emerge -qv sys-apps/plocate

# Install easy-to-use 'find' utility, fd.
clear
status "Installing fd, an easy-to-use 'find' utility..."
emerge -qv sys-apps/fd

# Install and start NTP daemon.
clear
status "Installing time synchronization daemon..."
emerge -qv net-misc/chrony
rc-update add chronyd default
rc-service chronyd start

# Install kmscon (optional).
bash "$SCRIPT_DIR"/modules/console-install.sh

# Install I/O Scheduler udev rules.
status "Installing I/O Scheduler udev rules..."
emerge -qv sys-block/io-scheduler-udev-rules

# Install filesystem tools.
clear
status "Installing filesystem tools..."
emerge -qv sys-fs/xfsprogs sys-fs/ntfs3g

# Install eselect repository tool.
clear
status "Installing eselect repository tool..."
emerge -qv app-eselect/eselect-repository

# Web browser installation.
bash "$SCRIPT_DIR"/modules/browser-install.sh

clear
status "Installing fonts..."
# Configure Nerd fonts.
bash "$SCRIPT_DIR"/modules/nerd-fonts-config.sh
# Install fonts.
emerge -qv media-fonts/nerd-fonts media-fonts/source-sans

# Update USE flags.
status "Updating USE flags..."
emerge -qvuND @world

# Clean up any orphaned/unneeded dependencies.
status "Removing any orphaned/undeeded dependencies..."
emerge -cq
emerge @preserved-rebuild

# Configure font rendering.
configure_font_rendering

# Allow the user to modify NetworkManager connections without root privileges.
status "Adding your user account to the 'plugdev' group..."
gpasswd -a "$name" plugdev

# Install sudo.
status "Installing sudo..."
emerge -qv app-admin/sudo

# Install Zsh (and oh-my-zsh from 'mv' overlay).
source "$SCRIPT_DIR"/modules/zsh-install.sh

# Install and configure command-line utilities.
source "$SCRIPT_DIR"/modules/cli-utils-install.sh

# Install and configure Helix editor.
source "$SCRIPT_DIR"/modules/helix-install.sh

# Fix user's config permissions!
chown -R "$name":"$name" /home/"$name"/.config

# Change user's shell to Zsh. Better shell.
status "Changing root/user's shell to Zsh..."
status "Setting the root user's default shell to Zsh..."
chsh -s /bin/zsh
status "Setting the user's default shell to Zsh..."
chsh -s /bin/zsh "$name"

# Remove temporary installation files.
status "Removing temporary installation files..."
rm /stage3-*.tar.*
rm -rf /gentoo-installer

# Install an enhanced adduser utility.
status "Installing an improved user management utility..."
emerge -qv app-admin/superadduser

# Install GRUB.
bash "$SCRIPT_DIR"/modules/grub-install.sh

# Exit chroot.
exit
