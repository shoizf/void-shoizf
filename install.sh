#!/usr/bin/env bash
###############################################################################
# Main installation script for void-shoizf setup
# Logs everything to a timestamped file outside the working directory.
# Run as a normal user (not root).
###############################################################################

set -euo pipefail

# --- Logging Setup ---
LOG_DIR="/var/log/void-shoizf"
LOG_FILE="$LOG_DIR/install_$(date '+%Y%m%d_%H%M%S').log"

# Fallback if /var/log is not writable (e.g., user session)
if [ ! -w "$(dirname "$LOG_DIR")" ]; then
  LOG_DIR="$HOME/.local/logs/void-shoizf"
  LOG_FILE="$LOG_DIR/install_$(date '+%Y%m%d_%H%M%S').log"
fi

mkdir -p "$LOG_DIR"
touch "$LOG_FILE" || {
  echo "❌ Cannot create log file at $LOG_FILE"
  exit 1
}

# Redirect stdout and stderr to tee (log + terminal)
exec > >(tee -a "$LOG_FILE") 2>&1

echo "📜 Logging installation output to: $LOG_FILE"
echo "------------------------------------------------------------"
echo "Started at: $(date)"
echo "User: $(whoami)"
echo "Working directory: $(pwd)"
echo "------------------------------------------------------------"
echo

# --- Check if running as root ---
if [[ "$(id -u)" -eq 0 ]]; then
  echo "❌ Don't run as sudo, exiting!"
  exit 1
fi

# --- Determine Target User and Home Directory ---
TARGET_USER=$(logname 2>/dev/null || whoami)
TARGET_USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

if [[ -z "$TARGET_USER" || -z "$TARGET_USER_HOME" ]]; then
  echo "❌ Could not determine target user or home directory."
  exit 1
fi
echo "Running installation for user: $TARGET_USER ($TARGET_USER_HOME)"

# --- CODE BLOCK A: Grant passwordless sudo temporarily ---
echo "🔐 Configuring temporary passwordless sudo..."
USER_NAME=$(whoami)
SUDOERS_FILE="/etc/sudoers"
BACKUP_FILE="/etc/sudoers.backup.$(date +%s)"

sudo cp -a "$SUDOERS_FILE" "$BACKUP_FILE"
echo "🧾 Backup created at: $BACKUP_FILE"

if ! sudo grep -q "^$USER_NAME" "$SUDOERS_FILE"; then
  echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" | sudo tee -a "$SUDOERS_FILE" >/dev/null
  echo "✅ Added passwordless sudo rule for $USER_NAME."
else
  echo "ℹ️ User already has sudo rule defined; skipping append."
fi

if sudo visudo -c >/dev/null 2>&1; then
  echo "✅ Sudoers syntax check passed."
else
  echo "❌ Invalid sudoers syntax! Restoring backup..."
  sudo cp -a "$BACKUP_FILE" "$SUDOERS_FILE"
  exit 1
fi

# --- Package Installation ---
PKG_CMD="xbps-install -Sy"
PACKAGES=(
  niri xdg-desktop-portal-wlr wayland xwayland-satellite
  polkit-kde-agent swaybg alacritty zsh walker Waybar wob
  mpc yazi pcmanfm pavucontrol swayimg cargo gammastep
  brightnessctl xdg-desktop-portal xdg-desktop-portal-gtk
  power-profiles-daemon firefox sddm tmux ripgrep fd tree
  xorg-server xf86-input-libinput dbus-libs dbus-x11 cups
  cups-filters acpi jq dateutils wlr-randr procps-ng
  playerctl unzip flatpak elogind nodejs mako lm_sensors
  wget scdoc liblz4-devel
)

echo "📦 Installing core packages..."
sudo $PKG_CMD "${PACKAGES[@]}"
echo "✅ Core packages installed successfully!"

# --- Udev Rules for Backlight ---
UDEV_RULES_DIR="/etc/udev/rules.d"
sudo mkdir -p "$UDEV_RULES_DIR"
UDEV_RULES_FILE="$UDEV_RULES_DIR/90-backlight.rules"
cat <<'EOF' | sudo tee "$UDEV_RULES_FILE" >/dev/null
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF
sudo udevadm control --reload
sudo udevadm trigger
echo "✅ Udev rules for backlight applied."

# --- Add User to Groups ---
GROUPS_TO_ADD=(video lp input)
for group in "${GROUPS_TO_ADD[@]}"; do
  if id -nG "$TARGET_USER" | grep -qw "$group"; then
    echo "User $TARGET_USER already in $group group."
  else
    sudo usermod -a -G "$group" "$TARGET_USER"
    echo "Added user $TARGET_USER to $group group."
  fi
done

# --- Run installer scripts ---
for script in add-font audio-integration niri hyprlock sddm_astronaut awww grub nvidia vulkan-intel intel dev-tools networkman; do
  echo "⚙️ Running installer: $script.sh ..."
  chmod +x "./installers/$script.sh"
  if [[ "$script" =~ grub|networkman ]]; then
    sudo "./installers/$script.sh"
  else
    "./installers/$script.sh" "$TARGET_USER" "$TARGET_USER_HOME"
  fi
  echo "✅ $script.sh completed successfully!"
done

# --- Enable System Services (runit) ---
SERVICE_DIR="/var/service"
enable_service() {
  local name="$1"
  local src="/etc/sv/$name"
  local dest="$SERVICE_DIR/$name"
  if [[ -d "$src" || -L "$src" ]]; then
    [[ -L "$dest" ]] || sudo ln -sf "$src" "$dest"
    echo "✅ Enabled $name service."
  else
    echo "⚠️ Service $name not found at $src."
  fi
}

enable_service power-profiles-daemon
enable_service NetworkManager
enable_service dbus

# --- CODE BLOCK B: Restore sudoers backup ---
echo "♻️ Restoring original sudoers..."
LATEST_BACKUP=$(ls -t /etc/sudoers.backup.* 2>/dev/null | head -n 1)
if [[ -n "$LATEST_BACKUP" ]]; then
  sudo cp -a "$LATEST_BACKUP" /etc/sudoers
  echo "✅ Restored from $LATEST_BACKUP"
else
  echo "⚠️ No sudoers backup found."
fi
sudo visudo -c >/dev/null 2>&1 && echo "✅ Verified restored sudoers."

# --- Wrap-up ---
echo
echo "🎉 Installation complete!"
echo "Log saved at: $LOG_FILE"
echo "Reboot recommended."
echo "------------------------------------------------------------"
echo "Ended at: $(date)"
