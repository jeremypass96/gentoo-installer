#!/bin/bash
# posy-cursors-install.sh - script to install Posy's cursors on Linux, since only the AUR from Arch Linux has them.
# Copyright (C) 2026 Jeremy Passarelli <recordguy96@aol.com>

echo ">>> Installing Posy cursors..."
echo ">>> Cloning Posy cursors GitHub repo..."
git clone https://github.com/Icelk/posy-cursors.git

echo ">>> Copying cursors to /usr/share/icons..."
sudo cp -rp posy-cursors/themes/posy-white /usr/share/icons/posy-cursors
sudo cp -rp posy-cursors/themes/posy-black /usr/share/icons/posy-cursors-black

echo ">>> Applying correct user permissions..."
sudo chown -R root:root /usr/share/icons/posy-cursors /usr/share/icons/posy-cursors-black
sudo find /usr/share/icons/posy-cursors /usr/share/icons/posy-cursors-black -type d -exec chmod 755 {} \;
sudo find /usr/share/icons/posy-cursors /usr/share/icons/posy-cursors-black -type f -exec chmod 644 {} \;

echo ">>> Removing GitHub repo directory from current directory..."
cd && rm -rf posy-cursors

echo ">>> Done. Posy cursors are now installed."
