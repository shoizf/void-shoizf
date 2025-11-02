#!/bin/sh
#
# Installer script for hyprlock and hypridle
# This script is called from the main install.sh

# --- Determine Target User and Home Directory ---
TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_USER_HOME" ]; then
  echo "❌ [hyprlock.sh] Could not determine target user or home directory."
  exit 1
fi
echo "Configuring Hyprlock for user: $TARGET_USER ($TARGET_USER_HOME)"

# --- 1. Add 3rd-Party Repo ---
echo "Adding Hyprland 3rd-party XBPS repository..."
echo "repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc" | sudo tee /etc/xbps.d/hyprland-void.conf

# --- 2. Sync and Install ---
echo "Syncing repositories and installing hyprlock/hypridle..."
echo "Please say 'Y' to trust the new repository key."
sudo xbps-install -S
sudo xbps-install -Sy hyprlock hypridle

# --- 3. Remove Old Swaylock ---
echo "Removing conflicting swaylock package..."
sudo xbps-remove -R swaylock

# --- 4. Set Permissions (MANDATORY) ---
echo "Setting 'setuid' bit on hyprlock binary..."
HYPRLOCK_PATH=$(which hyprlock)
if [ -n "$HYPRLOCK_PATH" ]; then
  sudo chmod a+s "$HYPRLOCK_PATH"
else
  echo "❌ [hyprlock.sh] ERROR: Could not find hyprlock binary to set permissions."
  exit 1
fi

# --- 5. Define All Paths ---
HYPR_CONFIG_DIR="$TARGET_USER_HOME/.config/hypr"
REPO_HYPR_CONFIG_DIR="./configs/hypr"

# We will install scripts to ~/.config/hypr/ for simplicity
SCRIPT_DEST_DIR="$TARGET_USER_HOME/.config/hypr"
WALLPAPER_DEST_PATH="$HYPR_CONFIG_DIR/assets/hyprlockbg.jpg"

echo "Creating config directories..."
sudo -u "$TARGET_USER" mkdir -p "$HYPR_CONFIG_DIR/assets"

# --- 6. Copy Configs and Scripts ---
echo "Copying scripts and wallpaper..."

# Copy wallpaper from the repo to the user's config
# (This assumes 'configs/hypr/assets/hyprlockbg.jpg' exists in your repo)
if [ -f "$REPO_HYPR_CONFIG_DIR/assets/hyprlockbg.jpg" ]; then
  sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/assets/hyprlockbg.jpg" "$WALLPAPER_DEST_PATH"
else
  echo "⚠️ [hyprlock.sh] Wallpaper not found in repo at '$REPO_HYPR_CONFIG_DIR/assets/hyprlockbg.jpg'. Skipping."
fi

# Copy the music scripts
sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/music-info.sh" "$SCRIPT_DEST_DIR/music-info.sh"
sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/music-progress.sh" "$SCRIPT_DEST_DIR/music-progress.sh"

# Make them executable
sudo -u "$TARGET_USER" chmod +x "$SCRIPT_DEST_DIR/music-info.sh"
sudo -u "$TARGET_USER" chmod +x "$SCRIPT_DEST_DIR/music-progress.sh"

# --- 7. Template and Install Config Files ---

# --- 7a. Template hyprlock.conf ---
echo "Templating hyprlock.conf..."
sudo -u "$TARGET_USER" sed \
  -e "s|__WALLPAPER_PATH__|$WALLPAPER_DEST_PATH|g" \
  -e "s|__SCRIPT_PATH__|$SCRIPT_DEST_DIR|g" \
  "$REPO_HYPR_CONFIG_DIR/hyprlock.conf" >"$HYPR_CONFIG_DIR/hyprlock.conf"

# --- 7b. Template hypridle.conf ---
echo "Detecting monitor for hypridle..."
# We must run wlr-randr as the user, not root
PRIMARY_MONITOR=$(sudo -u "$TARGET_USER" wlr-randr | awk '!/ / {print $1}' | head -n 1)

if [ -z "$PRIMARY_MONITOR" ]; then
  echo "⚠️ [hyprlock.sh] Could not detect monitor. Defaulting to 'eDP-1'."
  PRIMARY_MONITOR="eDP-1"
fi
echo "Using monitor: $PRIMARY_MONITOR"

echo "Templating hypridle.conf..."
sudo -u "$TARGET_USER" sed "s/__MONITOR__/$PRIMARY_MONITOR/g" \
  "$REPO_HYPR_CONFIG_DIR/hypridle.conf.template" >"$HYPR_CONFIG_DIR/hypridle.conf"

# --- 8. Grant Flatpak Permission ---
echo "Granting Flatpak permission for Brave media control..."
sudo -u "$TARGET_USER" flatpak override --user --talk-name=org.mpris.MediaPlayer2.player com.brave.Browser

echo "✅ Hyprlock and Hypridle configured."
