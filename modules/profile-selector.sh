#!/bin/bash
# -----------------------------------------------------------
# Gentoo Installer Module: System Profile Selector
# -----------------------------------------------------------
# Provides:
#   - Clean parsing of "eselect profile list" output
#   - Removal of ANSI color codes for safe menu creation
#   - Interactive dialog-based profile selection
#   - Automatic eselect profile application
#
# Notes:
#   Designed for use during the chroot phase of installation.
#   This script is intended to be called from the main
#   installer.
# -----------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "$1")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# View and set system profile using dialog
echo ">>> Configuring system profile..."

# Collect profiles from eselect
PROFILE_RAW=$(eselect profile list 2>/dev/null)

# Strip ANSI colors
PROFILE_CLEAN=$(printf "%s\n" "$PROFILE_RAW" | sed 's/\x1b\[[0-9;]*m//g')

declare -A "$PROFILE_MAP"
PROFILE_MENU=()

while IFS= read -r line; do
    # Match lines like:
    #  [1]   default/linux/amd64/23.0/desktop (stable)
    #  [2]   default/linux/amd64/23.0/systemd *
    if [[ "$line" =~ ^[[:space:]]*\[([0-9]+)\][[:space:]]+(.+)$ ]]; then
        idx="${BASH_REMATCH[1]}"
        desc="${BASH_REMATCH[2]}"
        PROFILE_MAP["$idx"]="$desc"
        PROFILE_MENU+=("$idx" "$desc")
    fi
done <<< "$PROFILE_CLEAN"

if [ "${#PROFILE_MENU[@]}" -eq 0 ]; then
    echo "ERROR: No profiles found!"
    echo "$PROFILE_CLEAN"
    exit 1
fi

TMP_PROFILE=$(mktemp)

dialog --clear \
       --backtitle "Gentoo Installer: Profile Selector" \
       --title "Select System Profile" \
       --menu "Choose the system profile to use:" \
       0 0 0 \
       "${PROFILE_MENU[@]}" 2>"$TMP_PROFILE"

PROFILE_CHOICE=$(<"$TMP_PROFILE")
rm -f "$TMP_PROFILE"

echo ">>> Setting system profile to ${PROFILE_CHOICE}..."
eselect profile set "${PROFILE_CHOICE}"

echo ">>> Profile updated."