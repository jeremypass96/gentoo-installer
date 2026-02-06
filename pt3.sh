#!/bin/bash
# This script automates the installation of Gentoo Linux with a distribution binary kernel.

# Re-read /etc/profile.
. /etc/profile

# Apply environment changes.
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

SCRIPT_DIR="$(cd -- "$(dirname -- "$1")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

# -------------
# Set hostname.
# -------------
DEFAULT_HOSTNAME="GentooBox"
if command -v dialog >/dev/null 2>&1; then
    HOSTNAME=$(
        dialog --clear \
               --backtitle "Gentoo Install: Hostname" \
               --title "System hostname" \
               --inputbox "Enter a hostname for this machine:" 8 60 "$DEFAULT_HOSTNAME" \
               3>&1 1>&2 2>&3
    )
    clear
    [ -z "$HOSTNAME" ] && HOSTNAME="$DEFAULT_HOSTNAME"
else
    read -r -p "Enter hostname [${DEFAULT_HOSTNAME}]: " HOSTNAME
    [ -z "$HOSTNAME" ] && HOSTNAME="$DEFAULT_HOSTNAME"
fi
echo ">>> Using hostname: $HOSTNAME"
HOSTNAME=${HOSTNAME:-GentooBox}
echo "$HOSTNAME" > /etc/hostname

# ---------------------------
# Desktop selection (dialog).
# ---------------------------
if ! command -v dialog >/dev/null 2>&1; then
    echo ">>> WARNING: dialog is not installed; skipping desktop chooser."
    echo ">>> Defaulting to: no desktop (CLI only)."
    DESKTOP_CHOICE="none"
else
    TMP_DESKTOP=$(mktemp)
    dialog --clear \
        --backtitle "Gentoo Installer" \
        --title "Desktop Environment" \
        --menu "Choose a desktop environment to install:" \
        0 0 0 \
        plasma  "KDE Plasma" \
        xfce    "Xfce" \
        mate    "MATE" \
        none    "No desktop (CLI only)" \
        custom  "No automated desktop (I'll configure it myself)" \
        2>"$TMP_DESKTOP"

    if [ $? -ne 0 ]; then
        DESKTOP_CHOICE="none"
    else
        DESKTOP_CHOICE=$(<"$TMP_DESKTOP")
    fi

    rm -f "$TMP_DESKTOP"
fi

INSTALL_PLASMA=false
INSTALL_XFCE=false
INSTALL_MATE=false

case "$DESKTOP_CHOICE" in
    plasma) INSTALL_PLASMA=true ;;
    xfce)   INSTALL_XFCE=true ;;
    mate)   INSTALL_MATE=true ;;
    none|custom|*) ;;
esac

echo ">>> Desktop choice: ${DESKTOP_CHOICE}"
echo

# ------------------------------
# Failsafe for USE flag changes.
# ------------------------------
USE_FILES=(
  kde
  xfce
  mate
  lightdm
  qttools
  sudo
  vscodium
  vlc
  audacity
  portaudio
  pipewire
  avahi
  installkernel
  module-rebuild
  grub
  networkmanager
  cups
)

BACKUP_DIR="/etc/portage/package.use/.install-backup.$(date +%s)"
mkdir -p "${BACKUP_DIR}"

# Backup existing files (if they exist).
for f in "${USE_FILES[@]}"; do
    if [[ -f "/etc/portage/package.use/${f}" ]]; then
        cp "/etc/portage/package.use/${f}" "${BACKUP_DIR}/${f}"
    fi
done

# --------------------
# Configure USE flags.
# --------------------

# KDE USE flags.
if [ "$INSTALL_PLASMA" = true ]; then
    cat << EOF > /etc/portage/package.use/kde
kde-plasma/plasma-meta -sdk -discover -flatpak -plymouth -thunderbolt -unsupported -wacom -xwayland
kde-apps/kde-apps-meta -pim -education -games -accessibility -graphics -multimedia -network -sdk -utils
kde-apps/kdecore-meta -webengine
kde-apps/ark zip
kde-apps/kdeutils-meta -webengine -gpg -plasma 7zip
kde-plasma/plasma-login-sessions -wayland
dev-qt/qtpositioning geoclue
EOF
    chmod go+r /etc/portage/package.use/kde
fi

# Xfce USE flags.
if [ "$INSTALL_XFCE" = true ]; then
    cat << EOF > /etc/portage/package.use/xfce
xfce-base/xfce4-meta archive editor image search
app-text/poppler -qt5
dev-libs/libdbusmenu gtk3
x11-libs/gdk-pixbuf jpeg tiff
EOF
    chmod go+r /etc/portage/package.use/xfce
fi

# MATE USE flags.
if [ "$INSTALL_MATE" = true ]; then
    cat << EOF > /etc/portage/package.use/mate
media-libs/libmatemixer pulseaudio
gnome-base/gvfs mtp
EOF
    chmod go+r /etc/portage/package.use/mate
fi

# LightDM USE flags.
if [ "$INSTALL_XFCE" = true ] || [ "$INSTALL_MATE" = true ]; then
    echo "x11-misc/lightdm -gnome" > /etc/portage/package.use/lightdm
    chmod go+r /etc/portage/package.use/lightdm
fi

# Configure USE flags for Qt tools.
echo "dev-qt/qttools -assistant -qml -designer" > /etc/portage/package.use/qttools
chmod go+r /etc/portage/package.use/qttools

# Configure USE flags for sudo.
echo "app-admin/sudo offensive -sendmail -ssl" > /etc/portage/package.use/sudo
chmod go+r /etc/portage/package.use/sudo

# Configure USE flag for VSCodium.
echo "app-editors/vscodium -wayland" > /etc/portage/package.use/vscodium
chmod go+r /etc/portage/package.use/vscodium

# Configure USE flags for VLC.
echo "media-video/vlc -bluray -chromaprint -chromecast -macosx-notifications -jack -mtp -vnc -sid -skins libplacebo" > /etc/portage/package.use/vlc
chmod go+r /etc/portage/package.use/vlc

# Configure USE flags for Audacity (PipeWire-as-JACK, no ALSA).
echo "media-sound/audacity id3tag -alsa" > /etc/portage/package.use/audacity
chmod go+r /etc/portage/package.use/audacity
echo "media-libs/portaudio jack -alsa" > /etc/portage/package.use/portaudio
chmod go+r /etc/portage/package.use/portaudio
echo "media-video/pipewire jack-sdk"> /etc/portage/package.use/pipewire
chmod go+r /etc/portage/package.use/pipewire

# Configure USE flags for Avahi.
echo "net-dns/avahi -gtk -qt6" > /etc/portage/package.use/avahi
chmod go+r /etc/portage/package.use/avahi

# Configure USE flags for the kernel.
echo "sys-kernel/installkernel dracut grub" > /etc/portage/package.use/installkernel
chmod go+r /etc/portage/package.use/installkernel

# Optional: global dist-kernel.
if ask_yes_no "Enable global 'dist-kernel' USE flag for all packages (*/* dist-kernel)?\n\nRecommended if you plan to use Gentoo's binary distribution kernel and want automatic module rebuilds." yes; then
    echo "*/* dist-kernel" > /etc/portage/package.use/module-rebuild
    chmod go+r /etc/portage/package.use/module-rebuild
    echo ">>> Enabled global dist-kernel USE flag."
else
    rm -f /etc/portage/package.use/module-rebuild
    echo ">>> Not enabling global dist-kernel USE flag."
fi

# Configure USE flags for GRUB.
echo "sys-boot/grub -themes fonts" > /etc/portage/package.use/grub
chmod go+r /etc/portage/package.use/grub

# -------------------------------------
# Optional: enable wireless networking.
# -------------------------------------
if ask_yes_no "Are you on a laptop and want to install wireless networking tools?" yes; then
    echo "net-misc/networkmanager -wext" > /etc/portage/package.use/networkmanager
    chmod go+r /etc/portage/package.use/networkmanager
else
    echo "net-misc/networkmanager --bluetooth -wifi -wext" > /etc/portage/package.use/networkmanager
    chmod go+r /etc/portage/package.use/networkmanager
fi

# ----------------------------------
# Optional: enable printing support.
# ----------------------------------
if ask_yes_no "Enable printing support?" yes; then
    echo "net-print/cups zeroconf" > /etc/portage/package.use/cups
    chmod go+r /etc/portage/package.use/cups
    echo ">>> Printing support enabled."
else
    echo ">>> Printing support not enabled."
fi

# ----------------------------------
# Optional: disable mp3 system-wide.
# ----------------------------------
if ask_yes_no "Disable MP3 support system-wide (set USE=\"-mp3 -mad -lame -mpg123\")?\n\nRecommended if you think MP3 is a trash format and prefer modern codecs." yes; then
    echo 'USE="-mp3 -mad -lame -mpg123"' >> /etc/portage/make.conf
    echo ">>> Global MP3 support disabled via USE flags."
else
    echo ">>> Leaving MP3 support enabled globally."
fi

# ---------------------------------
# Update system with new USE flags.
# ---------------------------------
if ! emerge -avquDN @world; then
    echo
    echo ">>> @world update FAILED. Restoring previous USE flag files..."
    for f in "${USE_FILES[@]}"; do
        if [[ -f "${BACKUP_DIR}/${f}" ]]; then
            mv "${BACKUP_DIR}/${f}" "/etc/portage/package.use/${f}"
        else
            rm -f "/etc/portage/package.use/${f}"
        fi
    done
    echo ">>> USE flag configuration rolled back."
    echo ">>> Fix the problem and rerun this step manually."
    exit 1
else
    rm -rf "${BACKUP_DIR}"
fi

# Clean up any orphaned/unneeded dependencies.
emerge -pv --depclean
emerge -a --depclean
emerge @preserved-rebuild

# ------------------------------------------------
# Desktop-specific installation.
# ------------------------------------------------
if [ "$INSTALL_PLASMA" = true ]; then
    echo ">>> Installing KDE Plasma..."
    emerge -qv kde-plasma/plasma-meta kde-apps/kde-apps-meta kde-apps/kdecore-meta kde-plasma/kwallet-pam kde-apps/kcalc kde-apps/kcharselect kde-apps/sweeper kde-misc/kweather sys-block/partitionmanager app-cdr/dolphin-plugins-mountiso kde-misc/kclock kde-misc/kdeconnect kde-apps/okular kde-apps/gwenview kde-plasma/plasma-firewall kde-apps/filelight kde-apps/ark

    if ask_yes_no "Do you want to install some KDE games?\n\nThis will install the following games:\n- Kapman\n- KPatience\n- KMines\n- Bomber\n- KSnakeDuel\n- Klickety\n- KBlocks\n- KDiamond\n- KBounce\n- KNetWalk\n- KBreakOut" yes; then
    emerge -qv kde-apps/kapman kde-apps/kpat kde-apps/kmines kde-apps/bomber kde-apps/ksnakeduel kde-apps/klickety kde-apps/kblocks kde-apps/kdiamond kde-apps/kbounce kde-apps/knetwalk kde-apps/kbreakout
    else
        echo ">>> No KDE games will be installed."
    fi

    # For kde-plasma/kinfocenter.
    emerge -qv x11-apps/xdpyinfo sys-apps/pciutils
    rc-update add power-profiles-daemon default

    # For kde-frameworks/kfilemetadata.
    emerge -qv app-text/catdoc

    # Enable SDDM and elogind.
    sed -i 's/DISPLAYMANAGER="xdm"/DISPLAYMANAGER="sddm"/' /etc/conf.d/display-manager
    rc-update add display-manager default
    rc-update add elogind boot && rc-service elogind start

    # Enable ufw for plasma-firewall.
    rc-update add ufw boot && rc-service ufw start

    # Fix KDE Connect bug.
    ufw allow 1714:1764/udp
    ufw allow 1714:1764/tcp
    rc-service ufw restart
else
    echo ">>> Skipping KDE Plasma installation (desktop choice: ${DESKTOP_CHOICE})."
fi

if [ "$INSTALL_XFCE" = true ]; then
    echo ">>> Installing Xfce..."

    emerge -1 xfce-extra/xfce4-notifyd
    emerge -qv xfce-base/xfce4-meta xfce-extra/xfce4-pulseaudio-plugin xfce-extra/xfce4-taskmanager x11-themes/xfwm4-themes app-cdr/xfburn xfce-extra/xfce4-sensors-plugin media-sound/pavucontrol
    env-update && . /etc/profile
    cat << EOF > /etc/pam.d/xfce4-screensaver
auth include system-auth
password include system-auth
EOF

    # Configure LightDM.
    echo XSESSION=\"Xfce4\" > /etc/env.d/90xsession
    env-update && source /etc/profile
fi

if [ "$INSTALL_MATE" = true ]; then
    echo ">>> Installing MATE..."
    emerge -qv mate-base/mate mate-extra/mate-tweak

    # Configure LightDM.
    echo XSESSION=\"Mate\" > /etc/env.d/90xsession
    env-update && source /etc/profile
fi

# ------------------------------------------------
# Display Manager for Xfce / MATE: LightDM
# ------------------------------------------------
if [ "$INSTALL_XFCE" = true ] || [ "$INSTALL_MATE" = true ]; then
    echo ">>> Installing LightDM display manager for Xfce/MATE..."
    emerge -qv x11-misc/lightdm x11-misc/lightdm-gtk-greeter

    # Set LightDM as display manager.
    sed -i 's/DISPLAYMANAGER="xdm"/DISPLAYMANAGER="lightdm"/' /etc/conf.d/display-manager
    rc-update add display-manager default

    # Make sure dbus is running.
    rc-update add dbus default

    # Make sure elogind is running (needed for session management).
    rc-update add elogind boot
    rc-service elogind start

    env-update && source /etc/profile

    echo ">>> LightDM configured for Xfce/MATE."
fi

if [ "$INSTALL_PLASMA" = true ] && [ "$INSTALL_XFCE" = true ] && [ "$INSTALL_MATE" = true ]; then
    emerge -qv x11-themes/papirus-icon-theme
fi

if [ "$INSTALL_PLASMA" = false ] && [ "$INSTALL_XFCE" = false ] && [ "$INSTALL_MATE" = false ]; then
    echo ">>> No desktop environment installed (choice: ${DESKTOP_CHOICE})."
    echo ">>> System remains CLI-only; you can install a DE later."
fi

# Install some nice Gentoo-specific scripts.
emerge -qv app-portage/gentoolkit

# Install Linux firmware.
echo ">>> Installing Linux firmware..."
emerge -qv sys-kernel/linux-firmware

# Configure dracut.
mkdir -p /etc/dracut.conf.d
echo 'kernel_cmdline="nowatchdog nmi_watchdog=0 net.ifnames=0"' >> /etc/dracut.conf.d/kernel.conf
dracut -f

# Install sys-kernel/installkernel.
emerge -qv sys-kernel/installkernel

# Update environment variables.
env-update

# -----------------------------------------------------------
# Kernel Selection
# -----------------------------------------------------------
TMP_KERNEL=$(mktemp)

dialog --clear \
    --backtitle "Gentoo Installer" \
    --title "Kernel Selection" \
    --menu "Choose which Linux kernel to install:" \
    0 0 0 \
    bin     "Gentoo Binary Kernel (gentoo-kernel-bin) - Fast, easy, works for everyone." \
    src     "Gentoo Source Kernel (gentoo-kernel) - For custom configs via menuconfig." \
    2>"$TMP_KERNEL"

KERNEL_CHOICE=$(<"$TMP_KERNEL")
rm -f "$TMP_KERNEL"

echo ">>> Kernel choice: $KERNEL_CHOICE"
echo
case "$KERNEL_CHOICE" in
    bin)
        echo ">>> Installing Gentoo binary kernel..."
        emerge -qv sys-kernel/gentoo-kernel-bin
        ;;

    src)
        echo ">>> Installing source kernel (gentoo-kernel)..."
        emerge -qv sys-kernel/gentoo-kernel
        ;;
esac

# Install and enable NetworkManager.
emerge -qv net-misc/networkmanager
rc-update add NetworkManager default

# Fix /etc/hosts.
if grep -q '^127\.0\.0\.1' /etc/hosts; then
    sed -i 's/^127\.0\.0\.1.*/127.0.0.1   '$HOSTNAME'/' /etc/hosts
else
    echo '127.0.0.1   '$HOSTNAME'' >> /etc/hosts
fi

# Install system logger.
emerge -qv app-admin/sysklogd
rc-update add sysklogd default

# Install cron daemon.
emerge -qv sys-process/cronie
rc-update add cronie default

# Add file indexing.
emerge -qv sys-apps/plocate

# Install and start Chrony.
emerge -qv net-misc/chrony
rc-update add chronyd default
rc-service chronyd start

# Add IO Scheduler udev rules.
emerge -qv sys-block/io-scheduler-udev-rules

# Install filesystem tools.
emerge -qv sys-fs/xfsprogs sys-fs/ntfs3g

# Install eselect repository tool.
emerge -qv app-eselect/eselect-repository

# -------------------------
# Web browser installation.
# -------------------------
TMP_BROWSER=$(mktemp)
    dialog --clear \
        --backtitle "Gentoo Installer" \
        --title "Web Browser" \
        --menu "Choose a web browser to install:" \
        0 0 0 \
        brave     "Brave (Privacy-based browser with ad-blocking, fingerprinting protection, etc.)" \
        firefox   "Mozilla Firefox" \
        chrome    "Google Chrome" \
        chromium  "Chromium (Open-source version of Google Chrome.)" \
        vivaldi   "Vivaldi" \
        none      "No web browser." \
        2>"$TMP_BROWSER"

        if [ $? -ne 0 ]; then
        BROWSER_CHOICE="none"
    else
        BROWSER_CHOICE=$(<"$TMP_BROWSER")
    fi

    rm -f "$TMP_BROWSER"

INSTALL_BRAVE=false
INSTALL_FIREFOX=false
INSTALL_CHROME=false
INSTALL_CHROMIUM=false
INSTALL_VIVALDI=false

case "$BROWSER_CHOICE" in
    brave)    INSTALL_BRAVE=true ;;
    firefox)  INSTALL_FIREFOX=true ;;
    chrome)   INSTALL_CHROME=true ;;
    chromium) INSTALL_CHROMIUM=true ;;
    vivaldi)  INSTALL_VIVALDI=true ;;
    none|*) ;;
esac

echo ">>> Browser choice: ${BROWSER_CHOICE}"
echo

if [ "$INSTALL_BRAVE" = true ]; then
    eselect repository enable another-brave-overlay
    emerge --sync another-brave-overlay
    echo "www-client/brave-browser" > /etc/portage/package.accept_keywords/brave-browser
    chmod go+r /etc/portage/package.accept_keywords/brave-browser
    emerge -qv www-client/brave-browser
    rm -f /usr/share/applications/com.brave.Browser.desktop
else
    echo ">>> Skipping Brave installation (Browser choice: ${BROWSER_CHOICE})."
fi

if [ "$INSTALL_FIREFOX" = true ]; then
    emerge -qv www-client/firefox-bin
else
    echo ">>> Skipping Firefox installation (Browser choice: ${BROWSER_CHOICE})."
fi

if [ "$INSTALL_CHROME" = true ]; then
    echo "www-client/google-chrome google-chrome" >> /etc/portage/package.license
    chmod go+r /etc/portage/package.license
    emerge -qv www-client/google-chrome
else
    echo ">>> Skipping Google Chrome installation (Browser choice: ${BROWSER_CHOICE})."
fi

if [ "$INSTALL_CHROMIUM" = true ]; then
    emerge -qv www-client/chromium
else
    echo ">>> Skipping Chromium installation (Browser choice: ${BROWSER_CHOICE})."
fi

if [ "$INSTALL_VIVALDI" = true ]; then
    echo "www-client/vivaldi Vivaldi" >> /etc/portage/package.license
    chmod go+r /etc/portage/package.license
    emerge -qv www-client/vivaldi
else
    echo ">>> Skipping Vivaldi installation (Browser choice: ${BROWSER_CHOICE})."
fi

if [ "$INSTALL_BRAVE" = false ] && [ "$INSTALL_FIREFOX" = false ] && [ "$INSTALL_CHROME" = false ] && [ "$INSTALL_CHROMIUM" = false ] && [ "$INSTALL_VIVALDI" = false ]; then
    echo ">>> No web browser installed (choice: ${BROWSER_CHOICE})."
    echo ">>> Script assumes you are installing a CLI-only system with no DE."
fi

# Install Nerd fonts.
eselect repository enable xarblu-overlay
emerge --sync xarblu-overlay
echo "media-fonts/nerd-fonts" > /etc/portage/package.accept_keywords/nerd-fonts
chmod go+r /etc/portage/package.accept_keywords/nerd-fonts
echo "media-fonts/nerd-fonts hermit" > /etc/portage/package.use/nerd-fonts
chmod go+r /etc/portage/package.use/nerd-fonts
emerge -qv --autounmask media-fonts/nerd-fonts
echo "media-fonts/nerd-fonts Vic-Fieger-License" >> /etc/portage/package.license
chmod go+r /etc/portage/package.license
emerge -qv media-fonts/nerd-fonts

# Install 'Source Sans Pro' font.
emerge -qv media-fonts/source-sans

# Clean up Noto fonts.
cat << EOF >> /etc/portage/package.use/noto-font
media-fonts/noto -extra
media-fonts/noto-emoji icons
EOF
chmod go+r /etc/portage/package.use/noto-font

# Update changed USE flags.
emerge --quiet --verbose --changed-use --deep --update @world

# Clean up any orphaned/unneeded dependencies.
emerge -pv --depclean
emerge -a --depclean
emerge @preserved-rebuild

# To modify NetworkManager connections without needing to enter the root password, adding our new user to the 'plugdev' group.
echo ">>> To modify NetworkManager connections as a normal user, adding your user account to the 'plugdev' group..."
gpasswd -a "$name" plugdev

# Install sudo.
emerge -qv app-admin/sudo

# Install Zsh (and oh-my-zsh from 'mv' overlay).
echo ">>> Installing Zsh with Gentoo's Zsh completions..."
emerge -qv app-shells/zsh app-shells/gentoo-zsh-completions
eselect repository enable mv
emerge --sync mv
emerge -aqv app-shells/oh-my-zsh
cp -v /usr/share/zsh/site-contrib/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc
sed -i 's|ZSH="$HOME/.oh-my-zsh"|ZSH="/usr/share/zsh/site-contrib/oh-my-zsh"|' /etc/skel/.zshrc
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="gentoo"/' /etc/skel/.zshrc
sed -i 's/# HYPHEN_INSENSITIVE="true"/HYPHEN_INSENSITIVE="true"/' /etc/skel/.zshrc
sed -i 's/'"# zstyle ':omz:update' mode disabled"'/'"zstyle ':omz:update' mode disabled"'/' /etc/skel/.zshrc
sed -i 's/# ENABLE_CORRECTION="true"/ENABLE_CORRECTION="true"/' /etc/skel/.zshrc
sed -i 's/# COMPLETION_WAITING_DOTS="true"/COMPLETION_WAITING_DOTS="true"/' /etc/skel/.zshrc
sed -i 's/# DISABLE_UNTRACKED_FILES_DIRTY="true"/DISABLE_UNTRACKED_FILES_DIRTY="true"/' /etc/skel/.zshrc
sed -i 's|# HIST_STAMPS="mm/dd/yyyy"|HIST_STAMPS="mm/dd/yyyy"|' /etc/skel/.zshrc
sed -i 's/plugins=(git)/plugins=(git colored-man-pages safe-paste sudo copypath zsh-autosuggestions zsh-syntax-highlighting)/' /etc/skel/.zshrc
ZSH_CUSTOM=/usr/share/zsh/site-contrib/oh-my-zsh/custom
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
echo "# Set the default umask." >> /etc/skel/.zshrc
echo "umask 077" >> /etc/skel/.zshrc
echo "" >> /etc/skel/.zshrc
echo "# Disable highlighting of pasted text." >> /etc/skel/.zshrc
echo "zle_highlight=('paste:none')" >> /etc/skel/.zshrc
echo "" >> /etc/skel/.zshrc
echo "# Apply sensible history settings." >> /etc/skel/.zshrc
echo "setopt HIST_EXPIRE_DUPS_FIRST" >> /etc/skel/.zshrc
echo "setopt HIST_FIND_NO_DUPS" >> /etc/skel/.zshrc
echo "setopt HIST_IGNORE_ALL_DUPS" >> /etc/skel/.zshrc
echo "setopt HIST_IGNORE_DUPS" >> /etc/skel/.zshrc
echo "setopt HIST_IGNORE_SPACE" >> /etc/skel/.zshrc
echo "setopt HIST_SAVE_NO_DUPS" >> /etc/skel/.zshrc
echo alias ls='"lsd"' >> /etc/skel/.zshrc
echo alias cat='"bat"' >> /etc/skel/.zshrc
echo fastfetch >> /etc/skel/.zshrc
echo "autoload -U compinit" >> /etc/skel/.zshrc
echo compinit >> /etc/skel/.zshrc
echo "zstyle ':completion::complete:*' use-cache 1" >> /etc/skel/.zshrc
cp -v /etc/skel/.zshrc /home/"$username"/.zshrc
cp -v /etc/skel/.zshrc ~/.zshrc

# Install and configure fastfetch.
mkdir -p /etc/skel/.config/fastfetch && cd /etc/skel/.config/fastfetch
wcurl https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/Dotfiles/config/fastfetch/config.jsonc
cd || exit
emerge -qv app-misc/fastfetch
mkdir -p /home/"$username"/.config/fastfetch && cp -v /etc/skel/.config/fastfetch/config.jsonc /home/"$username"/.config/fastfetch
chmod go+r /etc/skel/.config/fastfetch/config.jsonc
chown -R "$username":"$username" /home/"$username"/.config/fastfetch
chmod go+r /home/"$username"/.config/fastfetch/config.jsonc
mkdir -p ~/.config/fastfetch && cp -v /etc/skel/.config/fastfetch/config.jsonc ~/.config/fastfetch/

# Install and configure LSD (LSDeluxe).
mkdir -p /etc/skel/.config/lsd/ && cd /etc/skel/.config/lsd
wcurl https://raw.githubusercontent.com/jeremypass96/linux-stuff/refs/heads/main/Dotfiles/config/lsd/config.yaml
cd || exit
emerge -qv sys-apps/lsd
mkdir -p /home/"$username"/.config/lsd && cp -v /etc/skel/.config/lsd/config.yaml /home/"$username"/.config/lsd
chmod go+r /etc/skel/.config/lsd/config.yaml
chown -R "$username":"$username" /home/"$username"/.config/lsd
chmod go+r /home/"$username"/.config/lsd/config.yaml
mkdir -p ~/.config/lsd && cp -v /etc/skel/.config/lsd/config.yaml ~/.config/lsd

# Fix user's config permissions!
chown -R "$username":"$username" .config

# Remove leftover junk.
rm /stage3-*.tar.*
rm /install_gentoo_pt2.sh
rm /install_gentoo_pt3.sh

# Install proper adduser script.
emerge -qv app-admin/superadduser

# Install GRUB.
emerge -qv sys-boot/grub

# Install bootloader.
# Get the block device backing /.
ROOT_DEV=$(findmnt -no SOURCE /)
# Get the parent disk (e.g. sda from sda2, or nvme0n1 from nvme0n1p2).
DISK_NAME=$(lsblk -no PKNAME "$ROOT_DEV")
DRIVE="/dev/${DISK_NAME}"
if [[ -d /sys/firmware/efi ]]; then
    echo ">>> UEFI detected — installing GRUB for EFI..."
    mount "${DRIVE}1" /efi
    mkdir -p /efi/EFI
    grub-install --efi-directory=/efi --bootloader-id=Gentoo
    echo "GRUB_CFG=/efi/EFI/Gentoo/grub.cfg" > /etc/env.d/99grub
    env-update
    grub-mkconfig -o /efi/EFI/Gentoo/grub.cfg
else
    echo ">>> BIOS detected — installing GRUB for BIOS on $DRIVE..."
    grub-install "$DRIVE"
    grub-mkconfig -o /boot/grub/grub.cfg
fi

# Tweak /etc/rc.conf.
sed -i 's/#rc_autostart_user="YES"/rc_autostart_user="YES"/' /etc/rc.conf

echo "This ends the Gentoo installation script. Reboot and enjoy!"

# Exit chroot.
exit