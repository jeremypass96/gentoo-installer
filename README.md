# Gentoo Automated Installer
A fully interactive, dialog-driven installer for Gentoo Linux.
Provides automatic partitioning, filesystem setup, kernel installation, USE flag configuration, GPU detection, and desktop environment installation.

## Features
* Interactive dialog menus throughout the install.
* Automatic disk partitioning and formatting.
* Automatic fstab generation.
* Automatic swapfile creation.
* Automatically downloads and extracts Stage3.
* Automatic kernel installation (_binary or source_).
* CPU optimization detection (_-march, -mtune_).
* GPU / VIDEO_CARDS detection (_Radeon, AMDGPU, Intel, NVIDIA_).
* Locale configuration.
* Timezone selection.
* Eselect profile selector (_dialog-based_).

* Desktop environment selector (_dialog-based_):
    * KDE Plasma
    * Xfce
    * MATE

* Browser selection (_dialog-based_):
    * Brave
    * Firefox
    * Chrome
    * Ungoogled Chromium
    * Vivaldi
    * Cromite

* Optional KDE games installer.
* Automatic USE flag population.
* User creation.
* Automatic service enabling (elogind, SDDM, ufw, etc.).
* Modular scripts designed to be run in sequence.

## Script Overview
### setup.sh
Runs outside the chroot environment of the Gentoo LiveCD/DVD.

Handles:
* Automatic disk/partition setup.
* Filesystem creation.
* Partition mounting.
* Fstab generation.
* Swapfile creation (_dialog-based_).
* Stage3 download and extraction.
* Chroot preparation.

### pt2.sh
Runs inside the Gentoo environment.

Handles:
* Configures portage/updates the Gentoo repository.
* Mirror selection w/ Gentoo's "mirrorselect" tool.
* Profile selection (_dialog-based_).
* Automatic CPU optimizations.
* GPU auto-detection.
* Timezone configuration.
* Locale configuration.
* User creation.

### pt3.sh (**VERY** big script!)

Handles:
* Hostname configuration.
* USE flag configuration.
* Desktop environment installer (_dialog-based_).
    * KDE games installation when installing KDE (_Kapman, KPatience, KMines, Bomber, KSnakeDuel, Klickety, KBlocks, KDiamond, KBounce, KNetWalk, and KBreakOut_).
    * Papirus icon theme installation.
* Wireless networking installation (_optional, dialog-based_).
* CUPS installation (_optional, dialog-based_).
* Kernel installation.
* NetworkManager installation.
* System tools installation.
* Web browser installer (_dialog-based_).
