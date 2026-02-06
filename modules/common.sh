#!/bin/bash
# -----------------------------------------------------------
# Gentoo Installer: Common Helpers
# -----------------------------------------------------------

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_root() {
    if [ "$EUID" -ne 0 ]; then
        die "This script must be run as root."
    fi
}

# Returns 0 if in chroot, 1 if not.
is_in_chroot() {
    # Compare / and /proc/1/root; if they differ, we're in a chroot.
    local root_dev root_ino initroot_dev initroot_ino
    root_dev=$(stat -c '%d' /)
    root_ino=$(stat -c '%i' /)
    initroot_dev=$(stat -c '%d' /proc/1/root)
    initroot_ino=$(stat -c '%i' /proc/1/root)

    if [ "$root_dev:$root_ino" = "$initroot_dev:$initroot_ino" ]; then
        return 1  # NOT in chroot
    else
        return 0  # in chroot
    fi
}

require_chroot() {
    if ! is_in_chroot; then
        die "This script is intended to be run inside the Gentoo chroot."
    fi
}

require_not_chroot() {
    if is_in_chroot; then
        die "This script must be run outside the chroot (on the live system)."
    fi
}

# Yes/No helper: returns 0 for YES, 1 for NO.
# Usage: if ask_yes_no "Question?" yes; then ...; fi
ask_yes_no() {
    local prompt="$1"
    local default="${2:-yes}"
    local ans

    if command -v dialog >/dev/null 2>&1; then
        if [ "$default" = "yes" ]; then
            dialog --clear --stdout --yesno "$prompt" 0 0
            return $?
        else
            dialog --clear --stdout --defaultno --yesno "$prompt" 0 0
            return $?
        fi
    else
        while true; do
            read -r -p "$prompt [y/n] (default: $default): " ans
            ans="${ans,,}"  # lowercase
            case "$ans" in
                y|yes) return 0 ;;
                n|no)  return 1 ;;
                "")
                    if [ "$default" = "yes" ]; then
                        return 0
                    else
                        return 1
                    fi
                    ;;
                *) echo "Please answer y or n." ;;
            esac
        done
    fi
}