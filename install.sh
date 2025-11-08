#!/usr/bin/env bash
###############################################################################
# Main installation script for void-shoizf setup
# Run as a normal user (not root).
###############################################################################

set -e

# --- 1. Initial Setup & Checks ---

# Ensure NOT running as root
if [[ "$(id -u)" -eq 0 ]]; then
  echo "❌ Do not run this script as root. Run it as your normal user."
  exit 1
fi

TARGET_USER=$(whoami)
TARGET_USER_HOME=$HOME
echo "🚀 Starting installation for user: $TARGET_USER"

# --- 2. Sudo Keep-Alive (The "Capable" Fix for Password Prompts) ---
echo "🔑 Root permissions are needed. Please enter your password once."
if ! sudo -v; then
  echo "❌ Failed to obtain sudo privileges. Aborting."
  exit 1
fi

# Start a background loop to keep sudo alive
(while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &)

# --- 3. Logging Setup (Fixed for User Permissions) ---
# We log to the user's home directory to avoid /var/log permission errors.
LOG_DIR="$TARGET_USER_HOME/.local/state/void-shoizf/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date '+%Y%m%d_%H%M%S').log"
touch "$LOG_FILE"

echo "📜 Logging to: $LOG_FILE"

# Redirect all future output to both stdout and the log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "------------------------------------------------------------"
echo "Started at: $(date)"
echo "User: $TARGET_USER"
echo "------------------------------------------------------------"

# --- 4. Core Package Installation ---
# NOTE: Removed hypr*, sway* (handled by child installers)
PACKAGES="
  niri xdg-desktop-portal-wlr wayland xwayland-satellite
  polkit-kde-agent alacritty zsh walker Waybar wob
  mpc yazi pcmanfm pavucontrol swayimg gammastep
  brightnessctl xdg-desktop-portal xdg-desktop-portal-gtk
  power-profiles-daemon firefox sddm tmux ripgrep fd tree
  xorg-server xf86-input-libinput dbus-libs dbus-x11 cups
  cups-filters acpi jq dateutils wlr-randr procps-ng
  NetworkManager networkmanager-dmenu nm-tray playerctl
  unzip flatpak elogind nodejs mako lm_sensors
  wget curl git base-devel
"

echo "📦 Updating XBPS and installing core packages..."
sudo xbps-install -Syu
sudo xbps-install -Sy $PACKAGES
echo "✅ Core packages installed."

# --- 5. System Configuration ---

# Udev rules for backlight (allows brightness control without sudo)
echo "⚙️ Configuring udev rules for backlight..."
UDEV_FILE="/etc/udev/rules.d/90-backlight.rules"
sudo mkdir -p "$(dirname "$UDEV_FILE")"
cat <<EOF | sudo tee "$UDEV_FILE" >/dev/null
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF
sudo udevadm control --reload
sudo udevadm trigger

# Add user to necessary groups
echo "👤 Adding $TARGET_USER to system groups..."
for group in video lp input audio network; do
  # Only add if the group exists
  if getent group "$group" >/dev/null; then
    sudo usermod -a -G "$group" "$TARGET_USER"
  fi
done

# --- 6. Run Child Installers ---
# These scripts are expected to be in the ./installers/ directory.

run_installer() {
  local script="$1"
  if [[ -f "./installers/$script" ]]; then
    echo "➡️ Running child installer: $script"
    chmod +x "./installers/$script"
    # Pass user variables just in case the script needs them
    if ./installers/"$script" "$TARGET_USER" "$TARGET_USER_HOME"; then
      echo "✅ $script finished successfully."
    else
      echo "❌ $script FAILED."
      # We don't exit here so other independent parts can still finish
    fi
  else
    echo "⚠️ Warning: Installer '$script' not found."
  fi
}

echo "--- Starting Modular Installers ---"

# Order matters here.
run_installer "add-font.sh"
run_installer "audio-integration.sh"
run_installer "niri.sh"
run_installer "dev-tools.sh"

# Hyprlock/Idle (Handles its own 3rd party repo)
run_installer "hyprlock.sh"

# AWWW Wallpaper Daemon (Handles compiling from source)
run_installer "awww.sh"

# System-level installers (these will use sudo internally)
run_installer "sddm_astronaut.sh"
run_installer "grub.sh"
run_installer "networkmanager.sh"

# GPU Installers (User should ideally only run one, but we'll try them)
# You might want to make this interactive in the future.
# run_installer "nvidia.sh"
# run_installer "intel.sh"
# run_installer "vulkan-intel.sh"
echo "⚠️ Skipping GPU installers by default. Run them manually if needed."

# --- 7. Enable Services ---
echo "🔌 Enabling system services..."
enable_service() {
  local svc="$1"
  if [ -d "/etc/sv/$svc" ]; then
    if [ ! -L "/var/service/$svc" ]; then
      sudo ln -s "/etc/sv/$svc" "/var/service/"
      echo "   Enabled $svc"
    else
      echo "   $svc already enabled."
    fi
  fi
}

enable_service dbus
enable_service elogind
enable_service polkitd
enable_service NetworkManager
enable_service power-profiles-daemon
# SDDM is usually enabled by its own installer, but good to double-check
enable_service sddm

# --- 8. Final Wrap-up ---
echo "------------------------------------------------------------"
echo "🎉 Installation Complete!"
echo "📜 Full log available at: $LOG_FILE"
echo "👉 Please REBOOT your system now to apply all changes (groups, udev, services)."
echo "------------------------------------------------------------"
