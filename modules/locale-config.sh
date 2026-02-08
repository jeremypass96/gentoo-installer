#!/bin/bash
# locale-config.sh — Gentoo installer module for locale and language configuration.
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

# -----------------------------------------------------------
# Gentoo Installer Module: Locale Configuration
# -----------------------------------------------------------
# Provides:
#   - Language-group selection (English, Spanish, etc.).
#   - Locale selection with human-readable descriptions.
#   - Automatic /etc/locale.gen generation.
#   - Automatic locale-gen execution.
#   - Automatic eselect locale configuration.
#
# Notes:
#   This script is intended to be called from the main
#   installer.
# -----------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "$1")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# Configure locale using dialog, grouped by language.
echo ">>> Configuring locale..."

echo ">>> Building locale map from /etc/locale.gen..."

declare -A CODE_BY_INDEX
declare -A DESC_BY_INDEX
declare -A LANG_BY_INDEX
declare -A LANG_LABEL

index=1

# Collect: locale code, description, and "language family" (prefix before _ / . / @)
while read -r line; do
    # Match: code  # Description
    if [[ "$line" =~ ^[[:space:]]*#?[[:space:]]*([A-Za-z0-9_.@-]+)[[:space:]]*#[[:space:]]*(.+)$ ]]; then
        code="${BASH_REMATCH[1]}"
        desc="${BASH_REMATCH[2]}"

        CODE_BY_INDEX["$index"]="$code"
        DESC_BY_INDEX["$index"]="$desc"

        # Base language: prefix before '_' / '.' / '@'
        base_lang="${code%%[_\.@]*}"
        LANG_BY_INDEX["$index"]="$base_lang"

        # Create a label for the language group (e.g. "English", "Spanish", "Portuguese")
        if [[ -z "${LANG_LABEL[$base_lang]}" ]]; then
            # Strip " (Country...)" from description
            label_src="$desc"
            label_noparen="${label_src%% (*}"
            # Take the last word before parentheses (usually the language name)
            last_word=$(printf '%s\n' "$label_noparen" | awk '{print $NF}')
            if [[ -n "$last_word" ]]; then
                LANG_LABEL["$base_lang"]="$last_word"
            else
                LANG_LABEL["$base_lang"]="$base_lang"
            fi
        fi

        ((index++))
    fi
done < /etc/locale.gen

if [ "${#CODE_BY_INDEX[@]}" -eq 0 ]; then
    echo "!!! No locale entries found in /etc/locale.gen"
    exit 1
fi

##############################
# 1) Language group selection.
##############################

echo ">>> Building language groups menu..."

# Build "lang_code<TAB>label" lines and sort by label
lang_lines=$(
    for lang in "${!LANG_LABEL[@]}"; do
        printf "%s\t%s\n" "$lang" "${LANG_LABEL[$lang]}"
    done | sort -k2,2
)

LANG_MENU=()
while IFS=$'\t' read -r lang label; do
    [[ -z "$lang" ]] && continue
    LANG_MENU+=("$lang" "$label")
done <<< "$lang_lines"

TMP_LANG=$(mktemp)

dialog --clear \
       --backtitle "Gentoo Install: Locale" \
       --no-cancel \
       --title "Select language group" \
       --menu "Choose a language family (e.g. English, Spanish, French):" \
       0 0 0 \
       "${LANG_MENU[@]}" 2>"$TMP_LANG"

CHOSEN_LANG=$(<"$TMP_LANG")
rm -f "$TMP_LANG"

echo ">>> You selected language group: $CHOSEN_LANG"

###########################################
# 2) Locale selection within that language.
###########################################

echo ">>> Building locale list for '$CHOSEN_LANG'..."


# Build "global_idx<TAB>description" for that base language, sorted by description.
locale_lines=$(
    for i in "${!CODE_BY_INDEX[@]}"; do
        if [[ "${LANG_BY_INDEX[$i]}" == "$CHOSEN_LANG" ]]; then
            printf "%s\t%s\n" "$i" "${DESC_BY_INDEX[$i]}"
        fi
    done | sort -k2,2
)

# Now renumber these sequentially (1,2,3,...) for the dialog,
# while mapping local index -> global index.
declare -A LOCAL_TO_GLOBAL
LOCALE_MENU=()
local_idx=1

while IFS=$'\t' read -r global_idx desc; do
    [[ -z "$global_idx" ]] && continue
    LOCAL_TO_GLOBAL["$local_idx"]="$global_idx"
    LOCALE_MENU+=("$local_idx" "$desc")
    ((local_idx++))
done <<< "$locale_lines"

if [ "${#LOCALE_MENU[@]}" -eq 0 ]; then
    echo "!!! No locales found for language group '$CHOSEN_LANG'"
    exit 1
fi

TMP_LOCALE=$(mktemp)

dialog --clear \
       --backtitle "Gentoo Install: Locale" \
       --no-cancel \
       --title "Select specific locale" \
       --menu "Choose the specific locale you want to generate:" \
       0 0 0 \
       "${LOCALE_MENU[@]}" 2>"$TMP_LOCALE"

CHOICE_LOCAL_INDEX=$(<"$TMP_LOCALE")
rm -f "$TMP_LOCALE"

GLOBAL_INDEX="${LOCAL_TO_GLOBAL[$CHOICE_LOCAL_INDEX]}"
CHOSEN_CODE="${CODE_BY_INDEX[$GLOBAL_INDEX]}"

echo ">>> You selected locale: $CHOSEN_CODE"
echo ">>> Updating /etc/locale.gen so only this locale is active..."

cp /etc/locale.gen /etc/locale.gen.bak

# Rewrite /etc/locale.gen: only CHOSEN_CODE is uncommented.
awk -v code="$CHOSEN_CODE" '
/^[[:space:]]*#/ {
    line = $0
    sub(/^[[:space:]]*#/, "", line)
    sub(/^[[:space:]]+/, "", line)
    split(line, a, /[[:space:]]+/)
    loc = a[1]

    if (loc == code) {
        sub(/^[[:space:]]*#/, "", $0)
        print
    } else {
        print
    }
    next
}

{
    line = $0
    sub(/^[[:space:]]+/, "", line)
    split(line, a, /[[:space:]]+/)
    loc = a[1]

    if (loc == code)
        print
    else
        print "#" $0
}
' /etc/locale.gen.bak > /etc/locale.gen

# Remove backup before locale-gen
rm -f /etc/locale.gen.bak

echo ">>> Running locale-gen..."
locale-gen

################################
# 3) Auto-select eselect locale.
################################

echo ">>> Auto-selecting eselect locale..."

TARGET_LOCALE="${CHOSEN_CODE}.UTF-8"

# Check if that exact target exists in eselect's list
if LANG=C LC_ALL=C eselect locale list 2>/dev/null | grep -q " ${TARGET_LOCALE}\b"; then
    echo ">>> Setting LANG to ${TARGET_LOCALE} via eselect..."
    LANG=C LC_ALL=C eselect locale set "${TARGET_LOCALE}"
else
    echo "!!! Could not find ${TARGET_LOCALE} in eselect locale list."
    echo ">>> Available targets are:"
    LANG=C LC_ALL=C eselect locale list
    read -p ">>> Enter the number or name of the locale you want to set: " LOCALE_CHOICE
    LANG=C LC_ALL=C eselect locale set "${LOCALE_CHOICE}"
fi

#######################################################################################
# 4) Fix L10N for package installation so we don't install multiple unneeded languages.
#######################################################################################
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

# Reload env inside chroot
env-update >/dev/null 2>&1
. /etc/profile
export PS1="(chroot) $PS1"
