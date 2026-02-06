#!/bin/bash
# Gentoo Xlibre installation script.

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
emerge -f --autounmask=y --autounmask-write x11-base/xlibre-server
etc-update --automode -3
emerge -C x11-base/xorg-server
emerge -C x11-base/xorg-drivers
emerge x11-base/xlibre-server
emerge @x11-module-rebuild
emerge @preserved-rebuild

# Disable X11 support for SDDM. Pulls in x11-base/xorg-server.
echo "x11-misc/sddm -X" > /etc/portage/package.use/sddm
chmod go+r /etc/portage/package.use/sddm
emerge -uU x11-misc/sddm