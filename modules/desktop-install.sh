#!/bin/bash
# desktop-install.sh - Gentoo installer module for installing desktop environments.
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
# ----------------------------------------------------------------
# Gentoo Linux Installer Module: Desktop Environment Installation
# ----------------------------------------------------------------
# Installs and configures the selected desktop environment,
# display manager, and common graphical components.
# ---------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot
clear

if [ "$INSTALL_PLASMA" = true ]; then
	status "Installing KDE Plasma..."
	emerge -qv kde-plasma/plasma-meta kde-apps/kde-apps-meta kde-apps/kdecore-meta kde-plasma/kwallet-pam kde-apps/kcalc kde-apps/kcharselect kde-apps/sweeper kde-misc/kweather sys-block/partitionmanager app-cdr/dolphin-plugins-mountiso kde-misc/kclock kde-misc/kdeconnect kde-apps/okular kde-apps/gwenview kde-apps/filelight kde-apps/ark kde-apps/ffmpegthumbs kde-apps/audiocd-kio kde-apps/kwalletmanager

	if ask_yes_no "Do you want Dolphin to integrate with Git repositories?" yes; then
		emerge -qv kde-apps/dolphin-plugins-git
	fi

	mkdir -p /etc/skel/.config
	wcurl --curl-options="--progress-bar" -o /etc/skel/.config/kdeglobals https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/Dotfiles/config/kdeglobals
	mkdir -p /home/"$name"/.config
	cp -v /etc/skel/.config/kdeglobals /home/"$name"/.config/kdeglobals
	chown "$name":"$name" /home/"$name"/.config/kdeglobals

	if ask_yes_no "Do you want to install some KDE games?\n\nThis will install the following games:\n- Kapman\n- KPatience\n- KMines\n- Bomber\n- KSnakeDuel\n- Klickety\n- KBlocks\n- KDiamond\n- KBounce\n- KNetWalk\n- KBreakOut" yes; then
		emerge -qv kde-apps/kapman kde-apps/kpat kde-apps/kmines kde-apps/bomber kde-apps/ksnakeduel kde-apps/klickety kde-apps/kblocks kde-apps/kdiamond kde-apps/kbounce kde-apps/knetwalk kde-apps/kbreakout
	fi

	# For kde-plasma/kinfocenter.
	emerge -qv x11-apps/xdpyinfo sys-apps/pciutils
	rc-update add power-profiles-daemon default

	# For kde-frameworks/kfilemetadata.
	emerge -qv app-text/catdoc

	# Enable SDDM and elogind.
	sed -i 's/DISPLAYMANAGER="xdm"/DISPLAYMANAGER="sddm"/' /etc/conf.d/display-manager
	rc-update add display-manager default
	rc-update add elogind boot && rc-service elogind start

	# Enable ufw.
	rc-update add ufw boot && rc-service ufw start

	# Fix KDE Connect bug.
	ufw allow 1714:1764/udp
	ufw allow 1714:1764/tcp
	rc-service ufw restart
fi

if [ "$INSTALL_XFCE" = true ]; then
	status "Installing Xfce..."
	emerge -qv1 xfce-extra/xfce4-notifyd
	emerge -qv xfce-base/xfce4-meta xfce-extra/xfce4-pulseaudio-plugin xfce-extra/xfce4-taskmanager x11-themes/xfwm4-themes app-cdr/xfburn xfce-extra/xfce4-sensors-plugin media-sound/pavucontrol x11-misc/mugshot xfce-extra/xfce4-whiskermenu-plugin x11-themes/arc-theme
	env-update && . /etc/profile
	cat <<EOF >/etc/pam.d/xfce4-screensaver
auth include system-auth
password include system-auth
EOF

	# Configure LightDM.
	echo XSESSION=\"Xfce4\" >/etc/env.d/90xsession
	env-update && source /etc/profile
fi

if [ "$INSTALL_MATE" = true ]; then
	status "Installing MATE..."
	emerge -qv mate-base/mate mate-extra/mate-tweak x11-themes/arc-theme

	# Configure LightDM.
	echo XSESSION=\"Mate\" >/etc/env.d/90xsession
	env-update && source /etc/profile
fi

if [ "$INSTALL_CINNAMON" = true ]; then
	status "Installing Cinnamon..."
	emerge -av gnome-extra/cinnamon x11-terms/gnome-terminal gnome-extra/gnome-calculator media-gfx/gnome-screenshot media-gfx/eog app-text/evince gnome-extra/gnome-system-monitor app-arch/file-roller app-cdr/brasero x11-themes/arc-theme
	install -d -m 0750 /etc/sudoers.d
	tee /etc/sudoers.d/cinnamon >/dev/null <<'EOF'
%wheel  ALL=(root) NOPASSWD: /sbin/reboot
%wheel  ALL=(root) NOPASSWD: /sbin/halt
%wheel  ALL=(root) NOPASSWD: /sbin/poweroff
%wheel  ALL=(root) NOPASSWD: /sbin/shutdown
EOF
	chmod 440 /etc/sudoers.d/cinnamon
	visudo -cf /etc/sudoers.d/cinnamon
	visudo -c

	cat <<EOF >/etc/polkit-1/rules.d/55-allowing-actions.rules
polkit.addRule (function (action, subject)
{
  if (action.id == "org.freedesktop.upower.hibernate" ||
      action.id == "org.freedesktop.upower.suspend" ||
      action.id == "org.freedesktop.consolekit.system.stop" ||
      action.id == "org.freedesktop.consolekit.system.restart" &&
      subject.isInGroup ("wheel"))
      {
        return polkit.Result.YES;
      }
});
EOF
fi

if [ "$INSTALL_TDE" = true ]; then
	status "Installing TDE..."
	eselect repository add trinity-official git https://mirror.git.trinitydesktop.org/gitea/TDE/tde-packaging-gentoo.git
	emaint sync -r trinity-official
	echo "*/*::trinity-official ~amd64" >/etc/portage/package.accept_keywords/trinity-official
	chmod go+r /etc/portage/package.accept_keywords/trinity-official
	emerge -qv trinity-base/tdebase-meta trinity-base/tdm
	sed -i 's/DISPLAYMANAGER="xdm"/DISPLAYMANAGER="tdm"/' /etc/conf.d/display-manager
	rc-update add display-manager default
	rc-update add elogind boot && rc-service elogind start
	add_global_use_flag "pulseaudio pipewire"
	emerge -qv media-video/pipewire && echo "gentoo-pipewire-launcher &" /home/"$name"/.xprofile
	emerge -qv media-sound/pavucontrol
fi

# --------------------------------------
# Display Manager for Xfce/MATE/Cinnamon: LightDM
# --------------------------------------
case "$DESKTOP_CHOICE" in
xfce | mate | cinnamon)
	status "Installing LightDM display manager for $DESKTOP_CHOICE..."
	emerge -qv x11-misc/lightdm x11-misc/lightdm-gtk-greeter

	# Set LightDM as display manager.
	sed -i 's/DISPLAYMANAGER="xdm"/DISPLAYMANAGER="lightdm"/' /etc/conf.d/display-manager
	rc-update add display-manager default

	# Make sure dbus is running.
	rc-update add dbus default && rc-service dbus start

	# Make sure elogind is running (needed for session management).
	rc-update add elogind boot && rc-service elogind start

	if [ "$DESKTOP_CHOICE" = "cinnamon" ]; then
		emerge -qv gnome-extra/openrc-settingsd
		rc-update add openrc-settingsd default && rc-service openrc-settingsd start

		if grep -q '^hosts:' /etc/nsswitch.conf; then
			if ! grep -q '^hosts:.*\<myhostname\>' /etc/nsswitch.conf; then
				sed -i '/^hosts:/ s/$/ myhostname/' /etc/nsswitch.conf
			fi
		fi
	fi

	env-update && source /etc/profile

	success "LightDM configured for $DESKTOP_CHOICE."
	;;
esac

if [ "$DESKTOP_CHOICE" != "none" ]; then
	emerge -qv x11-themes/papirus-icon-theme
	bash "$SCRIPT_DIR"/modules/posy-cursors-install.sh
	bash "$SCRIPT_DIR"/modules/xlibre-install.sh
	# Enable 'haveged', a RNG.
	emerge -qv sys-apps/haveged
	rc-update add haveged boot && rc-service haveged start
	if ask_yes_no "Enable Windows-style hardware notifications?" yes; then
		bash "$SCRIPT_DIR"/modules/hardware-notify.sh
		if [ "$DESKTOP_CHOICE" = "plasma" ]; then
			echo "X-KDE-autostart-after=panel" >>"/home/$name/.config/autostart/hardware-notify.desktop"
		fi
	fi
fi

if [ "$DESKTOP_CHOICE" = "none" ]; then
	pause_msg "No desktop will be installed.\n\nSystem remains CLI-only; you can install a desktop later."
fi
