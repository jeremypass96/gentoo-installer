#!/bin/bash
# plymouth-theme-install.sh - script to install a decent Gentoo Plymouth theme.
# Copyright (C) 2026 Jeremy Passarelli <recordguy96@aol.com>

echo ">>> Cloning Plymouth theme repo..."
git -C "$HOME" clone https://gitlab.com/menelkir/plymouth-theme-gentoo-logo-new.git

echo ">>> Making theme directory..."
mkdir /usr/share/plymouth/themes/gentoo-logo-new

echo ">>> Copying theme to /usr/share/plymouth/themes/..."
cp -rv "$HOME"/plymouth-theme-gentoo-logo-new/* /usr/share/plymouth/themes/gentoo-logo-new
rm /usr/share/plymouth/themes/gentoo-logo-new/README.rst

echo ">>> Removing GitHub repo directory from user's home directory..."
rm -rf "$HOME"/plymouth-theme-gentoo-logo-new

echo ">>> Applying theme..."
plymouth-set-default-theme -R gentoo-logo-new