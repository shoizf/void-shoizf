#!/usr/bin/env bash
# installers/hyprlock.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

echo "Configuring Hyprlock for user: $TARGET_USER ($TARGET_USER_HOME)"

echo "Adding Hyprland 3rd-party XBPS repository..."
echo "repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc" | sudo tee /etc/xbps.d/hyprland-void.conf

echo "Syncing repositories and installing hyprlock/hypridle..."
echo "Please say 'Y' to trust the new repository key."
sudo xbps-install -S
sudo xbps-install -Sy hyprlock hypridle zsh playerctl

echo "Removing conflicting swaylock/swayidle packages..."
sudo xbps-remove -RF swaylock swayidle || true

echo "Setting 'setuid' bit on hyprlock binary..."
HYPRLOCK_PATH=$(which hyprlock)
if [ -n "$HYPRLOCK_PATH" ]; then
  sudo chmod a+s "$HYPRLOCK_PATH"
fi

sudoers_rule="$TARGET_USER ALL=(ALL) NOPASSWD: /usr/sbin/zzz"
if ! sudo grep -qF "$sudoers_rule" /etc/sudoers; then
  echo "$sudoers_rule" | sudo tee -a /etc/sudoers >/dev/null
fi

HYPR_CONFIG_DIR="$TARGET_USER_HOME/.config/hypr"
REPO_HYPR_CONFIG_DIR="$REPO_ROOT/configs/hypr"
SCRIPT_DEST_DIR="$HYPR_CONFIG_DIR"
WALLPAPER_DEST_PATH="$HYPR_CONFIG_DIR/assets/hyprlockbg.jpg"

sudo -u "$TARGET_USER" mkdir -p "$HYPR_CONFIG_DIR/assets"

if [ -f "$REPO_HYPR_CONFIG_DIR/assets/hyprlockbg.jpg" ]; then
  sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/assets/hyprlockbg.jpg" "$WALLPAPER_DEST_PATH"
fi

sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/music-info.sh" "$SCRIPT_DEST_DIR/music-info.sh"
sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/music-progress.sh" "$SCRIPT_DEST_DIR/music-progress.sh"
sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/battery-status.sh" "$SCRIPT_DEST_DIR/battery-status.sh"

sudo -u "$TARGET_USER" chmod +x "$SCRIPT_DEST_DIR/"*.sh

sudo -u "$TARGET_USER" sed -e "s|__WALLPAPER_PATH__|$WALLPAPER_DEST_PATH|g" \
  -e "s|__SCRIPT_PATH__|$SCRIPT_DEST_DIR|g" \
  "$REPO_HYPR_CONFIG_DIR/hyprlock.conf" >"$HYPR_CONFIG_DIR/hyprlock.conf"

sudo -u "$TARGET_USER" cp "$REPO_HYPR_CONFIG_DIR/hypridle.conf" "$HYPR_CONFIG_DIR/hypridle.conf"

sudo -u "$TARGET_USER" flatpak override --user --talk-name=org.mpris.MediaPlayer2.player com.brave.Browser

echo "✅ Hyprlock and Hypridle configured."
