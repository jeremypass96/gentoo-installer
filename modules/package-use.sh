#!/bin/bash
# package-use.sh - Gentoo installer module for configuring Portage USE flags.
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
# Gentoo Linux Installer Module: Portage USE Flag Configuration
# ----------------------------------------------------------------
# Configures global and package-specific USE flags required by the
# installer, including optional desktop and hardware features.
# ----------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
require_root
require_chroot

# Shared package.use entries.
# ---------------------------------
# Configure USE flags for Qt tools.
# ---------------------------------
echo "dev-qt/qttools -assistant -qml -designer" >/etc/portage/package.use/qttools
chmod go+r /etc/portage/package.use/qttools
#
# -----------------------------
# Configure USE flags for sudo.
# -----------------------------
echo "app-admin/sudo offensive -sendmail -ssl" >/etc/portage/package.use/sudo
chmod go+r /etc/portage/package.use/sudo
#
# --------------------------------
# Configure USE flag for VSCodium.
# --------------------------------
echo "app-editors/vscodium -wayland" >/etc/portage/package.use/vscodium
chmod go+r /etc/portage/package.use/vscodium
#
# ----------------------------
# Configure USE flags for VLC.
# ----------------------------
echo "media-video/vlc -bluray -chromaprint -chromecast -macosx-notifications -jack -mtp -vnc -sid -skins libplacebo theora matroska live" >/etc/portage/package.use/vlc
chmod go+r /etc/portage/package.use/vlc
#
# -------------------------------------------------------------
# Configure USE flags for Audacity (PipeWire-as-JACK, no ALSA).
# -------------------------------------------------------------
echo "media-sound/audacity id3tag -alsa" >/etc/portage/package.use/audacity
chmod go+r /etc/portage/package.use/audacity
echo "media-libs/portaudio jack -alsa" >/etc/portage/package.use/portaudio
chmod go+r /etc/portage/package.use/portaudio
echo "media-video/pipewire jack-sdk" >/etc/portage/package.use/pipewire
chmod go+r /etc/portage/package.use/pipewire
#
# ------------------------------
# Configure USE flags for Avahi.
# ------------------------------
AVAHI_USE="-gtk -qt6"
echo "net-dns/avahi ${AVAHI_USE}" >/etc/portage/package.use/avahi
chmod go+r /etc/portage/package.use/avahi
#
# ------------------------------
# Configure USE flag for man-db.
# ------------------------------
echo "sys-apps/man-db -manpager" >/etc/portage/package.use/man-db
chmod go+r /etc/portage/package.use/man-db
#
# --------------------------------------------
# Configure USE flag for replacement manpager.
# --------------------------------------------
echo "app-text/ansifilter -gui" >/etc/portage/package.use/manpager
chmod go+r /etc/portage/package.use/manpager
#
# -----------------------------------
# Configure USE flags for the kernel.
# -----------------------------------
echo "sys-kernel/installkernel dracut grub" >/etc/portage/package.use/installkernel
chmod go+r /etc/portage/package.use/installkernel
#
# -----------------------------
# Configure USE flags for GRUB.
# -----------------------------
echo "sys-boot/grub -themes fonts" >/etc/portage/package.use/grub
chmod go+r /etc/portage/package.use/grub
#
# -----------------------------------
# Configure USE flags for Noto fonts.
# -----------------------------------
cat <<EOF >>/etc/portage/package.use/noto-fonts
media-fonts/noto -extra
media-fonts/noto-emoji icons
EOF
chmod go+r /etc/portage/package.use/noto-fonts
#
# -----------------------------------
# Configure USE flags for Nerd fonts.
# -----------------------------------
echo "media-fonts/nerd-fonts hermit" >/etc/portage/package.use/nerd-fonts
chmod go+r /etc/portage/package.use/nerd-fonts
#
# -------------------------------
# Configure USE flags for OpenRC.
# -------------------------------
echo "sys-apps/openrc audit" >/etc/portage/package.use/openrc
chmod go+r /etc/portage/package.use/openrc
#
# ---------------------------------------
# Configure USE flags for Linux firmware.
# ---------------------------------------
echo "sys-kernel/linux-firmware compress-xz deduplicate" >/etc/portage/package.use/linux-firmware
chmod go+r /etc/portage/package.use/linux-firmware
#
# Optional package.use entries.
#
# ------------------------------------
# Optional: Enable global dist-kernel.
# ------------------------------------
if ask_yes_no $'Enable global \'dist-kernel\' USE flag for all packages (*/* dist-kernel)?\n\nRecommended if you plan to use Gentoo\'s binary distribution kernel and want automatic module rebuilds.' yes; then
	echo "*/* dist-kernel" >/etc/portage/package.use/module-rebuild
	chmod go+r /etc/portage/package.use/module-rebuild
fi
#
# -------------------------------------
# Optional: Enable wireless networking.
# -------------------------------------
if ask_yes_no "Are you on a laptop and want to install wireless networking tools?" yes; then
	echo "net-misc/networkmanager -wext -modemmanager -ppp" >/etc/portage/package.use/networkmanager
	chmod go+r /etc/portage/package.use/networkmanager
else
	echo "net-misc/networkmanager -wifi -wext -modemmanager -ppp" >/etc/portage/package.use/networkmanager
	chmod go+r /etc/portage/package.use/networkmanager
fi
#
# ----------------------------------
# Optional: Enable printing support.
# ----------------------------------
if ask_yes_no "Enable printing support?" yes; then
	AVAHI_USE+=" python"
	echo "net-dns/avahi ${AVAHI_USE}" >/etc/portage/package.use/avahi
	echo "net-print/cups zeroconf" >/etc/portage/package.use/cups
	chmod go+r /etc/portage/package.use/cups
	echo "net-print/hplip scanner hpijs" >/etc/portage/package.use/hplip
	chmod go+r /etc/portage/package.use/hplip
else
	add_global_use_flag "-cups"
fi
#
# -------------------------------------------
# Optional: Disable mp3 encoding system-wide.
# -------------------------------------------
if ask_yes_no "Disable mp3 encoding support system-wide?\n\nRecommended if you prefer lossless codecs like FLAC." yes; then
	add_global_use_flag "-lame"
fi
#
# ------------------------------------
# Optional: Disable bluetooth support.
# ------------------------------------
if ask_yes_no "Disable bluetooth support?" yes; then
	add_global_use_flag "-bluetooth"
fi
#
# -----------------------------------------------
# Optional: Desktop-specific package.use entries.
# -----------------------------------------------
case "$DESKTOP" in
plasma)
	cat <<EOF >/etc/portage/package.use/kde
kde-plasma/plasma-meta -sdk -discover -flatpak -plymouth -thunderbolt -unsupported -wacom -xwayland
kde-apps/kde-apps-meta -pim -education -games -accessibility -graphics -multimedia -network -sdk -utils
kde-apps/kdecore-meta -webengine
kde-apps/ark zip
kde-apps/kdeutils-meta -webengine -gpg -plasma 7zip
kde-plasma/plasma-login-sessions -wayland
dev-qt/qtpositioning geoclue
kde-apps/thumbnailers video
kde-plasma/powerdevil brightness-control
app-misc/ddcutil user-permissions
EOF
	;;

xfce)
	cat <<EOF >/etc/portage/package.use/xfce
xfce-base/xfce4-meta archive editor image search
app-text/poppler -qt5
dev-libs/libdbusmenu gtk3
x11-libs/gdk-pixbuf jpeg tiff
gnome-base/gvfs mtp
xfce-extra/xfce4-whiskermenu-plugin accountsservice
x11-themes/arc-theme xfce
EOF
	chmod go+r /etc/portage/package.use/xfce
	;;

mate)
	cat <<EOF >/etc/portage/package.use/mate
media-libs/libmatemixer pulseaudio
gnome-base/gvfs mtp
x11-themes/arc-theme mate
EOF
	chmod go+r /etc/portage/package.use/mate
	sed -i 's/ -modemmanager//' /etc/portage/package.use/networkmanager
	;;

cinnamon)
	cat <<EOF >/etc/portage/package.use/cinnamon
x11-libs/xapp introspection
dev-libs/libxmlb introspection
x11-terms/gnome-terminal -gnome-shell -nautilus
x11-themes/arc-theme cinnamon
EOF
	chmod go+r /etc/portage/package.use/cinnamon
	sed -i 's/ -modemmanager//' /etc/portage/package.use/networkmanager
	;;
esac

case "$DESKTOP" in
xfce | mate)
	cat <<EOF >/etc/portage/package.use/lightdm
x11-misc/lightdm -X -gnome
EOF
	chmod go+r /etc/portage/package.use/lightdm
	;;
esac
