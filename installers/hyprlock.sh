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
# Install all new dependencies (zsh is for the EnviiLock config)
sudo xbps-install -Sy hyprlock hypridle zsh playerctl

# --- 3. Remove Old "Shitty" Packages ---
echo "Removing conflicting swaylock/swayidle packages..."
sudo xbps-remove -RF swaylock swayidle

# --- 4. Set Permissions (MANDATORY) ---
echo "Setting 'setuid' bit on hyprlock binary..."
HYPRLOCK_PATH=$(which hyprlock)
if [ -n "$HYPRLOCK_PATH" ]; then
  sudo chmod a+s "$HYPRLOCK_PATH"
else
  echo "❌ [hyprlock.sh] ERROR: Could not find hyprlock binary to set permissions."
  exit 1
fi

# --- 5. Fix sudoers for 'zzz' (MANDATORY) ---
echo "Adding /usr/sbin/zzz to sudoers for passwordless suspend..."
# This is the "capable" way to add the rule:
# 1. Check if the *exact* rule already exists
# 2. If not, use tee -a to append it.
if ! sudo grep -q "$TARGET_USER ALL=(ALL) NOPASSWD: /usr/sbin/zzz" /etc/sudoers; then
  echo "$TARGET_USER ALL=(ALL) NOPASSWD: /usr/sbin/zzz" | sudo tee -a /etc/sudoers >/dev/null
else
  echo "Sudoers rule for 'zzz' already exists."
fi

# --- 6. Define All Paths ---
HYPR_CONFIG_DIR="$TARGET_USER_HOME/.config/hypr"
REPO_HYPR_CONFIG_DIR="./configs/hypr"
SCRIPT_DEST_DIR="$TARGET_USER_HOME/.config/hypr" # Scripts will live in the hypr config dir
WALLPAPER_DEST_PATH="$HYPR_CONFIG_DIR/assets/hyprlockbg.jpg"

echo "Creating config directories..."
sudo -u "$TARGET_USER" mkdir -p "$HYPR_CONFIG_DIR/assets"

# --- 7. Copy Configs and Scripts ---
echo "Copying scripts and wallpaper..."

# Copy wallpaper from the repo to the user's config
if [ -f "$REPO_HYPR_CONFIG_DIR/assets/hyprlockbg.jpg" ]; then
  sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/assets/hyprlockbg.jpg" "$WALLPAPER_DEST_PATH"
else
  echo "⚠️ [hyprlock.sh] Wallpaper not found in repo at '$REPO_HYPR_CONFIG_DIR/assets/hyprlockbg.jpg'. Skipping."
fi

# Copy the music & battery scripts
sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/music-info.sh" "$SCRIPT_DEST_DIR/music-info.sh"
sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/music-progress.sh" "$SCRIPT_DEST_DIR/music-progress.sh"
sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/battery-status.sh" "$SCRIPT_DEST_DIR/battery-status.sh"

# Make them executable
sudo -u "$TARGET_USER" chmod +x "$SCRIPT_DEST_DIR/music-info.sh"
sudo -u "$TARGET_USER" chmod +x "$SCRIPT_DEST_DIR/music-progress.sh"
sudo -u "$TARGET_USER" chmod +x "$SCRIPT_DEST_DIR/battery-status.sh"

# --- 8. Template and Install Config Files ---

# --- 8a. Template hyprlock.conf ---
echo "Templating hyprlock.conf..."
# This 'sed' command replaces the placeholders with the user's paths
sudo -u "$TARGET_USER" sed \
  -e "s|__WALLPAPER_PATH__|$WALLPAPER_DEST_PATH|g" \
  -e "s|__SCRIPT_PATH__|$SCRIPT_DEST_DIR|g" \
  "$REPO_HYPR_CONFIG_DIR/hyprlock.conf" >"$HYPR_CONFIG_DIR/hyprlock.conf"

# --- 8b. Copy hypridle.conf ---
# This file is 100% portable, so we just copy it.
echo "Copying portable hypridle.conf..."
sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/hypridle.conf" "$HYPR_CONFIG_DIR/hypridle.conf"

# --- 9. Grant Flatpak Permission ---
echo "Granting Flatpak permission for Brave media control..."
sudo -u "$TARGET_USER" flatpak override --user --talk-name=org.mpris.MediaPlayer2.player com.brave.Browser

echo "✅ Hyprlock and Hypridle configured."
