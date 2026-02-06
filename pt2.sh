#!/bin/bash
# This script automates the installation of Gentoo Linux with a distribution binary kernel.

# Finish chroot'ing into the system.
source /etc/profile
export PS1="(chroot) $PS1"

SCRIPT_DIR="$(cd -- "$(dirname -- "$1")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# Configure portage.
mkdir -p /etc/portage/repos.conf
cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf

# Update the Gentoo ebuild repository
emerge-webrsync

# Select mirrors.
emerge --quiet --verbose --oneshot app-portage/mirrorselect
mirrorselect -i -o >> /etc/portage/make.conf

# Update repository.
emerge --sync

# Install dialog.
if ! command -v dialog >/dev/null 2>&1; then
    echo ">>> Installing dialog for interactive menus..."
    emerge --quiet --ask sys-apps/dialog
fi

# View and set system profile.
bash "$SCRIPT_DIR"/modules/profile-selector.sh

# Run automatic Gentoo CPU optimizations shell script.
bash "$SCRIPT_DIR"/modules/cpu-optimizations.sh

# Configure VIDEO_CARDS variable.
bash "$SCRIPT_DIR"/modules/gpu-autodetect.sh

# Configure ACCEPT_LICENSE variable.
cat << EOF >> /etc/portage/make.conf
# Overrides the profile's ACCEPT_LICENSE default value
ACCEPT_LICENSE="-* @BINARY-REDISTRIBUTABLE @EULA"
EOF

# Configure system settings (e.g., timezone, locale).

# Set timezone.
bash "$SCRIPT_DIR"/modules/timezone-selector.sh

# Configure locale.
bash "$SCRIPT_DIR"/modules/locale-config.sh

# Auto-detect L10N from selected LANG.
LANG_VAL=$(locale | awk -F= '/^LANG=/{gsub(/"/,"",$2);print $2}')

# Fallback if LANG somehow isn't set.
if [ -z "$LANG_VAL" ]; then
    echo ">>> LANG is empty; defaulting L10N to en-US"
    L10N_VALUE="en-US"
else
    # Strip encoding, e.g. en_US.UTF-8 -> en_US.
    BASE_LANG=${LANG_VAL%%.*}

    # Convert underscore to dash, e.g. en_US -> en-US.
    L10N_VALUE=${BASE_LANG/_/-}
fi

# Handle weird cases like C or POSIX.
case "$L10N_VALUE" in
    C|POSIX|"")
        echo ">>> Non-translation locale detected ($L10N_VALUE); defaulting L10N to en-US"
        L10N_VALUE="en-US"
        ;;
esac

echo ">>> Setting package L10N to ${L10N_VALUE}..."
echo "*/* L10N: -* ${L10N_VALUE}" > /etc/portage/package.use/localization

# Set the root password.
passwd

# Add user to the system.
read -p "Enter your name for a user account (all lowercase): " name
useradd -m -G users,wheel,audio,cdrom,cdrw,cron,usb,lp,video -s /bin/bash "$name"
passwd "$name"
chfn "$name"

bash "$SCRIPT_DIR"/pt3.sh