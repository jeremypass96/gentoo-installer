#!/bin/bash
# -----------------------------------------------------------
# Gentoo Installer Module: Timezone Selector
# -----------------------------------------------------------
# Provides:
#   - Region selection (America, Europe, Asia, etc.)
#   - City/timezone selection based on region
#   - Automatic /etc/timezone configuration
#   - Automatic emerge --config sys-libs/timezone-data
#
# Notes:
#   This script is intended to be called from the main
#   installer.
# -----------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "$1")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

echo ">>> Configuring timezone..."

TMP_DIR=$(mktemp -d)
REGION_FILE="$TMP_DIR/regions.txt"
ZONE_FILE="$TMP_DIR/zones.txt"

# Extract region list (continents), filtering out unwanted directories
find /usr/share/zoneinfo -maxdepth 1 -type d -print \
    | sed 's|/usr/share/zoneinfo/||' \
    | grep -v "^usr$" \
    | grep -v "^posix$" \
    | grep -v "^right$" \
    | grep -v "^Etc$" \
    | grep -v "^GMT$" \
    | grep -v "^UCT$" \
    | grep -v "^Universal$" \
    | grep -v "^Zulu$" \
    | grep -v "^Factory$" \
    | grep -v "^zone\.tab$" \
    | grep -v "^posixrules$" \
    | tail -n +2 \
    | sort > "$REGION_FILE"

# Build dialog menu entries
MENU_ITEMS=()
i=1
while read -r region; do
    MENU_ITEMS+=("$i" "$region")
    i=$((i+1))
done < "$REGION_FILE"

# Ask user for region
REGION_CHOICE=$(dialog --clear \
    --title "Select Timezone Region" \
    --menu "Choose your geographical region:" 23 60 15 \
    "${MENU_ITEMS[@]}" \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    clear
    echo "Timezone selection cancelled."
    exit 1
fi

REGION=$(sed -n "${REGION_CHOICE}p" "$REGION_FILE")

# Build zone menu for chosen region
find "/usr/share/zoneinfo/$REGION" -maxdepth 1 -type f -print \
    | sed "s|/usr/share/zoneinfo/$REGION/||" \
    | grep -v "^GMT" \
    | grep -v "^UTC" \
    | grep -v "^Etc" \
    | sort > "$ZONE_FILE"

ZONE_ITEMS=()
i=1
while read -r zone; do
    ZONE_ITEMS+=("$i" "$zone")
    i=$((i+1))
done < "$ZONE_FILE"

# Ask user for city/timezone
ZONE_CHOICE=$(dialog --clear \
    --title "Select Timezone" \
    --menu "Choose your specific timezone:" 20 60 15 \
    "${ZONE_ITEMS[@]}" \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    clear
    echo "Timezone selection cancelled."
    exit 1
fi

ZONE=$(sed -n "${ZONE_CHOICE}p" "$ZONE_FILE")

FULL_TZ="${REGION}/${ZONE}"

# Apply timezone
echo "$FULL_TZ" > /etc/timezone

clear
echo ">>> Setting timezone to: $FULL_TZ"
emerge --config sys-libs/timezone-data

# Cleanup
rm -rf "$TMP_DIR"

# Set clock configuration.
if ask_yes_no "Enable local time instead of UTC?\n\nRecommended if you plan to (or already) dual-boot with Windows." yes; then
    sed -i 's/clock="UTC"/clock="local"/' /etc/conf.d/hwclock
else
    echo ">>> Leaving clock set as UTC time."
fi

echo ">>> Timezone configuration complete."