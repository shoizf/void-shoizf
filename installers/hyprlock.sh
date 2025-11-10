#!/usr/bin/env bash
# installers/hyprlock.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

echo "Configuring Hyprlock for user: $TARGET_USER ($TARGET_USER_HOME)"

# 1. Add the 3rd-party Hyprland repository
HYPR_REPO_URL="https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc"
REPO_CONF_FILE="/etc/xbps.d/99-hyprland-void.conf"

echo "Adding Hyprland 3rd-party XBPS repository..."
if [ ! -f "$REPO_CONF_FILE" ]; then
    echo "repository=$HYPR_REPO_URL" | sudo tee "$REPO_CONF_FILE" > /dev/null
else
    echo "ℹ️ Hyprland repo already configured."
fi

# 2. Install hyprlock and hypridle
# FIX: Add '-y' to auto-approve the repository key and installation
echo "Syncing repositories and installing hyprlock/hypridle..."
sudo xbps-install -Sy -y hyprlock hypridle

# 3. Copy configuration files from repo to user's config
SOURCE_CONFIG_DIR="$REPO_ROOT/configs/hypr"
TARGET_CONFIG_DIR="$TARGET_USER_HOME/.config/hypr"

echo "Ensuring hypr config directory exists: $TARGET_CONFIG_DIR"
# This script is run as $TARGET_USER from install.sh
mkdir -p "$TARGET_CONFIG_DIR"

echo "Copying configuration from $SOURCE_CONFIG_DIR..."
if [ -d "$SOURCE_CONFIG_DIR" ]; then
    cp -rT "$SOURCE_CONFIG_DIR" "$TARGET_CONFIG_DIR"
    echo "✅ Hyprlock configuration copied successfully."
else
    echo "❌ [hyprlock.sh] Source config directory not found: $SOURCE_CONFIG_DIR"
    exit 1
fi

echo "✅ [hyprlock.sh] Hyprlock setup finished."
