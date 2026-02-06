#!/bin/bash
# This script automates the installation of Gentoo Linux with a distribution binary kernel.

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_not_chroot

# Test if we have a network connection using Google's public IP address.
ping -c 4 8.8.8.8 || die "Network unreachable (ping to Google's public DNS server failed)"

# Test HTTPS access and DNS resolution.
curl --location gentoo.org --output /dev/null || die "DNS or HTTPS failed (cannot reach gentoo.org)"

# Update the system clock.
chronyd -q

# Detect drive(s).
echo ">>> Detecting available disks..."

mapfile -t DISKS < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}')

if [ "${#DISKS[@]}" -eq 0 ]; then
    echo "ERROR: No disks detected. Aborting."
    exit 1
elif [ "${#DISKS[@]}" -eq 1 ]; then
    DRIVE="${DISKS[0]}"
    echo ">>> Automatically selected drive: $DRIVE"
else
    if command -v dialog >/dev/null 2>&1; then
        echo ">>> Multiple disks detected, launching dialog selector..."

        MENU_ITEMS=()
        for dev in "${DISKS[@]}"; do
            # Grab size + model for nicer display
            info=$(lsblk -dpno SIZE,MODEL "$dev" | sed 's/  */ /g')
            MENU_ITEMS+=("$dev" "$info")
        done

        CHOSEN_DISK=$(
            dialog --clear \
                   --backtitle "Gentoo Install: Disk Selection" \
                   --title "Select target disk" \
                   --menu "Choose the disk to partition and install Gentoo onto (THIS WILL BE WIPED):" \
                   18 72 8 \
                   "${MENU_ITEMS[@]}" \
                   3>&1 1>&2 2>&3
        )
        clear

        if [ -z "$CHOSEN_DISK" ]; then
            echo "No disk selected. Aborting."
            exit 1
        fi

        DRIVE="$CHOSEN_DISK"
        echo ">>> Selected drive: $DRIVE"
    else
        echo "Multiple disks detected:"
        lsblk -dpno NAME,SIZE,MODEL | grep -E "sd|hd|vd|nvme|mmc"
        read -r -p "Enter disk to use (example: /dev/sda or /dev/nvme0n1): " DRIVE
    fi
fi

if [[ -d /sys/firmware/efi ]]; then
    echo ">>> UEFI detected — creating GPT partition table on $DRIVE..."
    parted -s "$DRIVE" mklabel gpt

    EFI_PARTITION="${DRIVE}1"
    ROOT_PARTITION="${DRIVE}2"

    echo ">>> EFI system partition will be: $EFI_PARTITION"
    echo ">>> Root partition will be: $ROOT_PARTITION"

    echo ">>> Creating and formatting EFI system partition..."
    parted -s "$DRIVE" mkpart primary fat32 1MiB 1GiB
    parted -s "$DRIVE" set 1 esp on
    mkfs.vfat -F 32 "$EFI_PARTITION"
    mkdir -p /efi/EFI

    echo ">>> Creating and formatting root partition..."
    parted -s "$DRIVE" mkpart primary xfs 1GiB 100%
    mkfs.xfs -f "$ROOT_PARTITION"

    echo ">>> Mounting root partition..."
    mount "$ROOT_PARTITION" /mnt/gentoo

    echo ">>> Mounting EFI system partition..."
    mkdir -p /mnt/gentoo/efi
    mount "$EFI_PARTITION" /mnt/gentoo/efi
else
    echo ">>> BIOS detected — creating MBR partition table on $DRIVE..."
    parted -s "$DRIVE" mklabel msdos

    BOOT_PARTITION="${DRIVE}1"
    ROOT_PARTITION="${DRIVE}2"

    echo ">>> Boot partition will be: $BOOT_PARTITION"
    echo ">>> Root partition will be: $ROOT_PARTITION"

    echo ">>> Creating and formatting boot partition..."
    parted -s "$DRIVE" mkpart primary xfs 1MiB 1GiB
    parted -s "$DRIVE" set 1 boot on
    mkfs.xfs -f "$BOOT_PARTITION"

    echo ">>> Creating and formatting root partition..."
    parted -s "$DRIVE" mkpart primary xfs 1GiB 100%
    mkfs.xfs -f "$ROOT_PARTITION"

    echo ">>> Mounting root partition..."
    mount "$ROOT_PARTITION" /mnt/gentoo

    echo ">>> Mounting boot partition..."
    mkdir -p /mnt/gentoo/boot
    mount "$BOOT_PARTITION" /mnt/gentoo/boot
fi

# Generate fstab.
if [[ -d /sys/firmware/efi ]]; then
cat << EOF >> /etc/fstab
$EFI_PARTITION      /efi         vfat    noauto,noatime        1 2
/swapfile           none         swap    sw                    0 0
$ROOT_PARTITION      /           xfs     defaults,noatime      0 1

/dev/cdrom          /mnt/cdrom   auto    noauto,user           0 0
EOF
else
cat << EOF >> /etc/fstab
$BOOT_PARTITION     /boot       xfs      defaults             0 2
/swapfile           none        swap     sw                   0 0
$ROOT_PARTITION     /           xfs      defaults,noatime     0 1

/dev/cdrom          /mnt/cdrom   auto    noauto,user          0 0
EOF
fi

# Make swapfile and activate it.
SWAP_SIZE_MB=8192   # default

if command -v dialog >/dev/null 2>&1; then
    CHOSEN_SWAP=$(
        dialog --clear \
               --backtitle "Gentoo Install: Swapfile" \
               --title "Swapfile size" \
               --menu "Select swapfile size (MiB):" 15 60 5 \
               2048 "2 GiB (light systems)" \
               4096 "4 GiB (8 GiB RAM typical)" \
               8192 "8 GiB (default)" \
               16384 "16 GiB (heavy workloads)" \
               3>&1 1>&2 2>&3
    )
    clear

    # If user pressed ESC, keep default
    if [ -n "$CHOSEN_SWAP" ]; then
        SWAP_SIZE_MB="$CHOSEN_SWAP"
    fi
else
    read -r -p "Swapfile size in MiB [8192]: " INPUT_SWAP
    case "$INPUT_SWAP" in
        "" )  ;;              # keep default
        * )  SWAP_SIZE_MB="$INPUT_SWAP" ;;
    esac
fi

if [ "$SWAP_SIZE_MB" -gt 0 ]; then
    echo ">>> Creating ${SWAP_SIZE_MB} MiB swapfile..."
    dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_SIZE_MB"
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
else
    echo ">>> Skipping swapfile creation."
fi

# Copy scripts to /mnt/gentoo before chroot'ing.
mkdir -p /mnt/gentoo/gentoo-installer
cp -rv $SCRIPT_DIR/pt2.sh /mnt/gentoo/gentoo-installer
cp -rv $SCRIPT_DIR/pt3.sh /mnt/gentoo/gentoo-installer
# Copy over the rest of the scripts, just in case!
mkdir -p /mnt/gentoo/gentoo-installer/modules
cp -v $SCRIPT_DIR/modules/*.sh /mnt/gentoo/gentoo-installer/modules

# Enter the /mnt/gentoo directory.
cd /mnt/gentoo || exit

# Download and extract the Gentoo stage3 tarball.
BASEURL="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc"
LATEST_TXT="${BASEURL}/latest-stage3-amd64-desktop-openrc.txt"

echo ">>> Detecting latest stage3 tarball..."
STAGE3=$(wget -qO- "${LATEST_TXT}" | awk '/^stage3-amd64-desktop-openrc-/ {print $1; exit}')

echo ">>> Latest stage3 is: ${STAGE3}"
echo ">>> Downloading stage3 and checksums..."
wget "${BASEURL}/${STAGE3}"
wget "${BASEURL}/${STAGE3}.CONTENTS.gz"
wget "${BASEURL}/${STAGE3}.sha256"
wget "${BASEURL}/${STAGE3}.DIGESTS"
wget "${BASEURL}/${STAGE3}.asc"

echo ">>> Verifying stage3 checksums..."
sha256sum --check "${STAGE3}.sha256"
gpg --import /usr/share/openpgp-keys/gentoo-release.asc
gpg --verify "${STAGE3}".asc
gpg --output "${STAGE3}.DIGESTS.verified" --verify "${STAGE3}.DIGESTS"
gpg --output "${STAGE3}.sha256.verified" --verify  "${STAGE3}.sha256"

echo ">>> Extracting stage3 tarball..."
UNPACK_SIZE=$(xz --robot -lv "${STAGE3}" | awk 'NR==2 {print $5}')
xz -dc "${STAGE3}" | pv -s "${UNPACK_SIZE}" | tar xpf - --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

# Copy DNS info to the new system.
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

echo "This ends part 1 of the Gentoo installation script. Run ./pt2.sh for part 2."

echo ">>> Chroot'ing into the Gentoo install..."
# Chroot into the new environment (also mounts filesystems).
arch-chroot /mnt/gentoo