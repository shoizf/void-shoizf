[shoi@void-shoizf ~]$ cat ~/Downloads/void-shoizf.txt
# ===================================================================
#           Void Linux & niri: shoizf's Setup Guide
# ===================================================================
#      🐧 The Definitive Void + NVIDIA Installation Guide
# ===================================================================
#       Assembled on: 2025-10-22
#       Final method: Staged configuration (Post-Reboot)
# ===================================================================

# ### 1. Live Environment Setup ###

# Connect to Wi-Fi (IMPORTANT: Replace with your details)
wpa_passphrase "YourSSID" "YourPassword" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
# Find your Wi-Fi interface name (e.g., wlan0, wlo1) using: ip a
wpa_supplicant -B -i wlo1 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
dhcpcd wlo1

# Partition the disk (MANUAL STEP) - e.g., fdisk /dev/nvme0n1
# Create partitions for: EFI, Swap, and Root.

# Format partitions and activate swap (IMPORTANT: Replace partition numbers)
mkswap /dev/nvme0n1p6
mkfs.ext4 /dev/nvme0n1p7
swapon /dev/nvme0n1p6

# Mount filesystems (IMPORTANT: Replace partition numbers)
mount /dev/nvme0n1p7 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi


# ### 2. Base Installation and Chroot ###

# Install base system and xtools
REPO=https://repo-default.voidlinux.org/current
ARCH=x86_64
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
XBPS_ARCH=$ARCH xbps-install -Sy -r /mnt -R "$REPO" base-system xtools

# Generate fstab and enter the chroot
xgenfstab -U /mnt > /mnt/etc/fstab
xchroot /mnt /bin/bash


# ### 3. System Configuration (Inside Chroot) ###

# --- Hostname, Keymap, Font, and Clock ---
echo "void-hp" > /etc/hostname
echo 'KEYMAP="us"' > /etc/rc.conf
xbps-install -S neovim terminus-font
echo 'FONT="ter-v22b"' >> /etc/rc.conf # Set the Terminus font
# We are NOT setting HARDWARECLOCK because your Windows is configured to use UTC.

# --- Locale and Timezone ---
# 1. Manually enable your chosen locale (MANUAL STEP).
nvi /etc/default/libc-locales
#    Inside, uncomment the line for "en_IN UTF-8" (Esc, :wq).

# 2. Generate the locale.
xbps-reconfigure -f glibc-locales
#    IMPORTANT: If you see "Cannot set locale" errors, exit and re-enter the chroot.

# 3. Set the default LANG variable.
echo "LANG=en_IN.UTF-8" > /etc/locale.conf

# 4. Set the timezone.
ln -sf /usr/share/zoneinfo/Asia/Dubai /etc/localtime

# --- User and Password Setup ---
passwd
useradd -m -s /bin/bash -G wheel,audio,video,input,network,storage,_seatd shoi
passwd shoi

# --- Sudoers Configuration ---
# Choose ONE of the following methods to grant sudo access to the 'wheel' group.
# Method A (Manual & Recommended): Run this command to safely edit the sudoers file.
EDITOR=nvim visudo
#    Inside the editor, find the line '# %wheel ALL=(ALL) ALL' and remove the '# '. Then save and exit.
#
# Method B (Automated): Uncomment the line below to run the automated command.
# sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# --- System Update and Core Packages ---
xbps-install -Su
xbps-install -S void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree

# --- GRUB Stage 1: Installation (Inside Chroot) ---
xbps-install -S grub-x86_64-efi efibootmgr os-prober ntfs-3g

# Configure os-prober and add NVIDIA modeset to the kernel parameters.
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub

# Install GRUB to the EFI directory
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void"

# Generate a TEMPORARY config that will let you boot Void Linux
grub-mkconfig -o /boot/grub/grub.cfg


# ### 4. Finalization ###

# Final reconfiguration, exit, and reboot
xbps-reconfigure -fa
exit
umount -R /mnt
reboot


# ###################################################################
# ### 🚀 STAGE 2: Post-Reboot Configuration                      ###
# ###################################################################
# Once you've booted into your new Void Linux system, open a terminal
# and perform these final steps.

# --- System Update ---
sudo xbps-install -Su

# --- 2. Install CPU Microcode (VITAL STEP) ---
# This package from the nonfree repo provides critical bug fixes for your Intel CPU.
sudo xbps-install -S intel-ucode

# --- 3. GRUB Stage 2: Add Windows ---
# sudo grub-mkconfig -o /boot/grub/grub.cfg

# --- 4. NVIDIA Driver Installation ---
# a. Install Kernel Headers (find version with 'uname -r')
uname -r
sudo xbps-install -S linux<version>-headers
#
# b. Install the NVIDIA drivers and related packages.
sudo xbps-install -Sy nvidia nvidia-libs nvidia-libs-32bit nvidia-vaapi-driver mesa-dri mesa-dri-32bit mesa-demos noto-fonts-ttf-variable noto-fonts-emoji niri xdg-desktop-portal-wlr wayland xwayland-satellite seatd polkit-kde-agent swaybg swayidle alacritty walker Waybar firefox sddm tmux font-firacode ripgrep fd curl tree -f
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' /etc/default/grub

# c. Blacklist the default Nouveau driver to prevent conflicts.
echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf

# --- 5. Regenerate Initramfs (VITAL STEP) ---
# This applies the microcode, driver, and module changes to your boot image.
# First, find your kernel package version (e.g., 'linux6.8' from '6.8.9_1'):
uname -r

# Then, run the reconfigure command with that version.
sudo xbps-reconfigure -f linux<version>

# --- 6. Reboot ---
# A final reboot is needed for the microcode and drivers to load.
sudo reboot

# --- 7. NVIDIA Driver Verification (After second reboot) ---
lsmod | grep nvidia
lsmod | grep nouveau
nvidia-smi
prime-run glxinfo | grep "renderer"


# ===========================================
# === Niri Wayland Desktop Environment    ===
# ===========================================

# ---- Install Niri, Wayland goods, SDDM graphical login, and essentials ----
  LazyVim: 
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git

  Oh-my tmux: 
  curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash

# ---- Add user to _seatd group for device access ----
sudo usermod -aG _seatd shoi

# ---- Enable seatd service ----
sudo ln -s /etc/sv/seatd /var/service/
sudo ln -s /etc/sv/dbus   /var/service/

# ---- Enable SDDM Display Manager login (graphical login) ----
sudo ln -s /etc/sv/sddm /var/service/

# -------------------------------------------------------------
# System will now boot with a full graphical login via SDDM
# Clicking Niri in SDDM will start your Wayland desktop properly!
# -------------------------------------------------------------

# === Core runtime setup for Niri + seatd + dbus ===

# Ensure runtime directory exists and is owned by your user
sudo mkdir -p /run/user/$(id -u)
sudo chown shoi:shoi /run/user/$(id -u)
sudo chmod 700 /run/user/$(id -u)

# Export runtime dir for this session
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# === Launch Niri under dbus ===
dbus-run-session -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" niri[shoi@void-shoizf ~]$


export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
env | grep XDG_RUNTIME_DIR

dbus-run-session -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" niri -v
