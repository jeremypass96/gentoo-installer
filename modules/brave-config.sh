#!/bin/bash
# brave-config.sh - Gentoo installer module for configuring Brave Browser.
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
# ----------------------------------------------------------
# Gentoo Linux Installer Module: Brave Browser Configuration
# ----------------------------------------------------------
# Configures Brave Browser with sensible default settings,
# disables unwanted Brave features and advertisements, and
# installs a default set of Gentoo bookmarks for new users.
# ---------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
	info "Installing 'jq' package for Brave configuration..."
	emerge -q app-misc/jq
fi

BRAVE_TEMPLATE="/root/.config/BraveSoftware/gentoo-template"
BRAVE_PROFILE="$BRAVE_TEMPLATE/Default"

timeout 5 brave-browser-stable \
	--headless \
	--no-sandbox \
	--user-data-dir="$BRAVE_TEMPLATE" >/dev/null 2>&1 || true

PREFERENCES="$BRAVE_PROFILE/Preferences"

for ((i = 0; i < 50; i++)); do
	[[ -f "$PREFERENCES" ]] && break
	sleep 0.1
done

jq '
    .bookmark_bar.show_on_all_tabs = true |
    .bookmark_bar.show_tab_groups = false |
    .brave.location_bar_is_wide = true |
    .omnibox.prevent_url_elisions = true |
    .brave.rewards.show_brave_rewards_button_in_location_bar = false |
    .brave.wallet.show_wallet_icon_on_toolbar = false |
    .brave.new_tab_page.show_brave_news = false |
    .brave.new_tab_page.show_rewards = false |
    .brave.new_tab_page.sponsored_images.survey_panelist = false |
    .brave.ai_chat.show_toolbar_button = false |
    .brave.ai_chat.storage_enabled = false |
    .brave.ai_chat.context_menu_enabled = false |
    .brave.show_side_panel_button = false |
    .brave.brave_ads.should_allow_ads_subdivision_targeting = false
' "$PREFERENCES" >"$PREFERENCES.tmp" &&
	mv "$PREFERENCES.tmp" "$PREFERENCES"

BOOKMARKS="$BRAVE_PROFILE/Bookmarks"
DATE_ADDED=$(($(date +%s) * 1000000 + 11644473600000000))
BOOKMARK_GUID_1=$(cat /proc/sys/kernel/random/uuid)
BOOKMARK_GUID_2=$(cat /proc/sys/kernel/random/uuid)
BOOKMARK_GUID_3=$(cat /proc/sys/kernel/random/uuid)

jq -n \
	--arg date "$DATE_ADDED" \
	--arg guid1 "$BOOKMARK_GUID_1" \
	--arg guid2 "$BOOKMARK_GUID_2" \
	--arg guid3 "$BOOKMARK_GUID_3" \
	'{
        checksum: "",
        roots: {
            bookmark_bar: {
                children: [
                    {
                        date_added: $date,
                        date_last_used: "0",
                        guid: $guid1,
                        id: "5",
                        name: "Gentoo Packages",
                        type: "url",
                        url: "https://packages.gentoo.org/"
                    },
                    {
                        date_added: $date,
                        date_last_used: "0",
                        guid: $guid2,
                        id: "6",
                        name: "Gentoo Wiki",
                        type: "url",
                        url: "https://wiki.gentoo.org/wiki/Main_Page"
                    },
                    {
                        date_added: $date,
                        date_last_used: "0",
                        guid: $guid3,
                        id: "7",
                        name: "Gentoo Forums",
                        type: "url",
                        url: "https://forums.gentoo.org/"
                    }
                ],
                date_added: $date,
                date_last_used: "0",
                date_modified: $date,
                guid: $guid1,
                id: "1",
                name: "Bookmarks bar",
                type: "folder"
            },
            other: {
                children: [],
                date_added: $date,
                date_last_used: "0",
                date_modified: "0",
                guid: $guid2,
                id: "2",
                name: "Other bookmarks",
                type: "folder"
            },
            synced: {
                children: [],
                date_added: $date,
                date_last_used: "0",
                date_modified: "0",
                guid: $guid3,
                id: "3",
                name: "Mobile bookmarks",
                type: "folder"
            }
        },
        version: 1
    }' >"$BOOKMARKS"

SKEL_BRAVE="/etc/skel/.config/BraveSoftware/Brave-Browser/Default"
mkdir -p "$SKEL_BRAVE"
cp "$PREFERENCES" "$SKEL_BRAVE/Preferences"
cp "$BOOKMARKS" "$SKEL_BRAVE/Bookmarks"

USER_HOME="/home/$name"
USER_BRAVE="$USER_HOME/.config/BraveSoftware/Brave-Browser/Default"
mkdir -p "$USER_BRAVE"
cp "$PREFERENCES" "$USER_BRAVE/Preferences"
cp "$BOOKMARKS" "$USER_BRAVE/Bookmarks"

chown -R "$name:$name" "$USER_HOME/.config/BraveSoftware"

# Cleanup
emerge -ac app-misc/jq
rm -rf "$BRAVE_TEMPLATE"
