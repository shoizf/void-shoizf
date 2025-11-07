#!/bin/sh

# Main installation script for void-shoizf setup
# Should be run as the target user (e.g., 'shoi') from within the cloned repository directory.
# Commands requiring root privileges will use 'sudo' internally.

# --- Check if running as root ---
if [ "$(id -u)" -eq 0 ]; then
  echo "❌ Don't run as sudo, exiting!" >&2 # Print error to stderr
  exit 1
fi

# --- Determine Target User and Home Directory (Running as non-root) ---
TARGET_USER=$(logname || whoami) # Get the user running the script
TARGET_USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_USER_HOME" ]; then
  echo "❌ Could not determine target user or home directory. Please run this script as the intended user."
  exit 1
fi
echo "Running installation for user: $TARGET_USER ($TARGET_USER_HOME)"

# --- CODE BLOCK A: Grant passwordless sudo for current user ---
echo "🔐 Configuring temporary passwordless sudo..."

# Store current user and timestamped backup
USER_NAME=$(whoami)
SUDOERS_FILE="/etc/sudoers"
BACKUP_FILE="/etc/sudoers.backup.$(date +%s)"

# Backup sudoers safely
sudo cp -a "$SUDOERS_FILE" "$BACKUP_FILE"
echo "🧾 Backup created at: $BACKUP_FILE"

# Append NOPASSWD rule for current user (if not already present)
if ! sudo grep -q "^$USER_NAME" "$SUDOERS_FILE"; then
  echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" | sudo tee -a "$SUDOERS_FILE" >/dev/null
  echo "✅ Added passwordless sudo rule for $USER_NAME."
else
  echo "ℹ️  User already has sudo rule defined; skipping append."
fi

# Validate syntax to ensure no lockouts
if sudo visudo -c >/dev/null 2>&1; then
  echo "✅ Sudoers syntax check passed."
else
  echo "❌ Error: sudoers syntax invalid! Restoring backup..."
  sudo cp -a "$BACKUP_FILE" "$SUDOERS_FILE"
  exit 1
fi

# --- Package Installation ---
PKG_CMD="xbps-install -Sy"
# List CORE packages (fonts and audio handled by sub-scripts)
PACKAGES="
    niri xdg-desktop-portal-wlr wayland xwayland-satellite 
    polkit-kde-agent swaybg alacritty zsh walker Waybar 
    wob mpc yazi pcmanfm pavucontrol swayimg cargo
    gammastep brightnessctl xdg-desktop-portal 
    xdg-desktop-portal-gtk power-profiles-daemon firefox 
    sddm tmux ripgrep fd tree xorg-server xf86-input-libinput 
    dbus-libs dbus-x11 cups cups-filters acpi jq dateutils 
    wlr-randr procps-ng playerctl unzip flatpak elogind 
    nodejs mako lm_sensors wget scdoc liblz4-devel
"

echo "Starting core package installation (will require sudo password)..."
sudo $PKG_CMD $PACKAGES

if [ $? -eq 0 ]; then
  echo "✅ Core packages installed successfully!"
else
  echo "❌ Core package installation failed! Check the output for errors."
  exit 1
fi

# --- Udev Rules for Backlight ---
UDEV_RULES_DIR="/etc/udev/rules.d"
echo "Checking/Creating directory $UDEV_RULES_DIR (will require sudo password)..."
sudo mkdir -p "$UDEV_RULES_DIR"

UDEV_RULES_FILE="$UDEV_RULES_DIR/90-backlight.rules"
echo "Creating udev rules for backlight permissions at $UDEV_RULES_FILE (will require sudo password)..."
cat <<EOF | sudo tee $UDEV_RULES_FILE >/dev/null
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF

echo "Reloading udev rules (will require sudo password)..."
sudo udevadm control --reload
sudo udevadm trigger

# --- Add User to Groups ---
GROUPS_TO_ADD="video lp input"
echo "Checking and adding user $TARGET_USER to necessary groups (will require sudo password)..."
for group in $GROUPS_TO_ADD; do
  if id -nG "$TARGET_USER" | grep -qw $group; then
    echo "User $TARGET_USER is already in the $group group."
  else
    echo "Adding user $TARGET_USER to $group group..."
    sudo usermod -a -G $group "$TARGET_USER"
    echo "User $TARGET_USER added to $group group. Log out/in required for changes to take full effect."
  fi
done

# --- Execute Modular Installers from Local Repo ---

echo "Running Font installation script..."
chmod +x ./installers/add-font.sh
if ./installers/add-font.sh; then
  echo "✅ Font installation finished successfully!"
else
  echo "❌ Font installation script failed during execution!"
fi

echo "Running Audio integration script..."
chmod +x ./installers/audio-integration.sh
if ./installers/audio-integration.sh; then
  echo "✅ Audio integration finished successfully!"
else
  echo "❌ Audio integration script failed during execution!"
  exit 1 # Audio is critical
fi

echo "Configuring Niri..."
chmod +x ./installers/niri.sh
# Pass user and home dir to the script if it needs them
if ./installers/niri.sh "$TARGET_USER" "$TARGET_USER_HOME"; then
  echo "✅ Niri configuration finished successfully!"
else
  echo "❌ Niri configuration script failed."
fi

# ... Implementing hyprlock

echo "Configuring Hyprlock and Hypridle..."
chmod +x ./installers/hyprlock.sh
if ./installers/hyprlock.sh "$TARGET_USER" "$TARGET_USER_HOME"; then
  echo "✅ Hyprlock configuration finished successfully!"
else
  echo "❌ Hyprlock configuration script failed."
fi

echo "Configuring Hyprlock and Hypridle..."
chmod +x ./installers/hyprlock.sh
# Pass user and home dir to the script
if ./installers/hyprlock.sh "$TARGET_USER" "$TARGET_USER_HOME"; then
  echo "✅ Hyprlock configuration finished successfully!"
else
  echo "❌ Hyprlock configuration script failed."
fi

echo "Installing SDDM Astronaut theme..."
chmod +x ./installers/sddm_astronaut.sh
if ./installers/sddm_astronaut.sh; then
  echo "✅ SDDM Astronaut theme installation finished successfully!"
else
  echo "❌ SDDM Astronaut theme installation script failed."
fi

# Setting up some Wallpapers
echo "Configuring AWWW (Wallpaper Daemon)..."
chmod +x ./installers/awww.sh
if ./installers/awww.sh "$TARGET_USER" "$TARGET_USER_HOME"; then
  echo "✅ AWWW configuration finished successfully!"
else
  echo "❌ AWWW configuration script failed."
fi

echo "Setting up GRUB theme (will require sudo password)..."
chmod +x ./installers/grub.sh
if sudo ./installers/grub.sh; then
  echo "✅ GRUB theme setup completed successfully."
else
  echo "❌ GRUB theme setup script failed!"
fi

# --- GPU Installers ---
echo "Executing NVIDIA installer script..."
chmod +x ./installers/nvidia.sh
if ./installers/nvidia.sh; then
  echo "✅ NVIDIA installer finished successfully!"
else
  echo "❌ NVIDIA installer failed!"
fi

echo "Executing Vulkan Intel installer script..."
chmod +x ./installers/vulkan-intel.sh
if ./installers/vulkan-intel.sh; then
  echo "✅ Vulkan Intel installer finished successfully!"
else
  echo "❌ Vulkan Intel installer failed!"
fi

echo "Executing Intel GPU installer script..."
chmod +x ./installers/intel.sh
if ./installers/intel.sh; then
  echo "✅ Intel GPU installer finished successfully!"
else
  echo "❌ Intel GPU installer failed!"
fi

# --- LzyVim and oh my tmux!
echo "Configuring Developer Tools (Nvim, Tmux)..."
chmod +x ./installers/dev-tools.sh
# Pass user and home dir to the script
if ./installers/dev-tools.sh "$TARGET_USER" "$TARGET_USER_HOME"; then
  echo "✅ Developer Tools configuration finished successfully!"
else
  echo "❌ Developer Tools configuration script failed."
  # Decide if this is a critical failure, e.g.: exit 1
fi

# Enable dbus service first (if not already enabled)
echo "Ensuring dbus service is enabled and running..."
if [ ! -L /var/service/dbus ]; then
  echo "Creating symlink for dbus service..."
  sudo ln -s /etc/sv/dbus /var/service/
fi

echo "Starting dbus service..."
sudo sv up dbus

# Run NetworkManager installer script from installers directory
echo "Executing NetworkManager installer script..."
chmod +x ./installers/networkman.sh
if ./installers/networkmanager.sh; then
  echo "✅ NetworkManager installer finished successfully!"
else
  echo "❌ NetworkManager installer failed!"
fi

# --- Enable System Services (runit) ---
echo "Enabling system services (runit - requires sudo password)..."
SERVICE_DIR="/var/service"

enable_service() {
  local service_name="$1"
  local service_path="/etc/sv/$service_name"
  local target_link="$SERVICE_DIR/$service_name"

  if [ ! -d "$service_path" ] && [ ! -L "$service_path" ]; then
    echo "❓ Service definition not found for $service_name at $service_path. Skipping enable."
    return 1
  fi

  if [ ! -L "$target_link" ]; then
    echo "Enabling $service_name service..."
    sudo ln -sf "$service_path" "$target_link"
  else
    echo "$service_name service already enabled."
  fi
}

# --- CODE BLOCK B: Restore sudoers from backup ---
echo "♻️  Restoring original sudoers configuration..."

# Find the most recent backup created by Block A
LATEST_BACKUP=$(ls -t /etc/sudoers.backup.* 2>/dev/null | head -n 1)

if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP" ]; then
  sudo cp -a "$LATEST_BACKUP" /etc/sudoers
  echo "✅ Restored sudoers from: $LATEST_BACKUP"
else
  echo "⚠️  No sudoers backup found. Manual verification recommended!"
fi

# Validate after restore
if sudo visudo -c >/dev/null 2>&1; then
  echo "✅ Sudoers restore verified successfully."
else
  echo "❌ Warning: restored sudoers file has syntax issues!"
fi

# Enable services needed by this desktop config
enable_service power-profiles-daemon
enable_service NetworkManager
enable_service dbus
# SDDM and DBUS system services should already be enabled per INSTALLATION.md Stage 3

echo "✅ System services checked/enabled."

# --- Cleanup Removed ---

echo "🎉 Main installation script finished!"
echo "Please address any manual steps noted (e.g., rmpc setup)."
echo "Waybar configuration needs to be applied separately."
echo "A final reboot is recommended before using the full desktop environment."
