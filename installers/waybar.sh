#!/usr/bin/env bash
# installers/waybar.sh
# Automated Waybar installer for Void Linux — non-interactive, safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_SRC="$REPO_ROOT/configs/waybar"

LOG_DIR="/var/log/void-shoizf"
LOG_FILE="$LOG_DIR/waybar-install.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 🧱 Installing Waybar configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Determine target user (if script is run as root)
if [[ $EUID -eq 0 ]]; then
  TARGET_USER=${SUDO_USER:-$(logname || whoami)}
  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  echo "Detected root execution: configuring Waybar for user '$TARGET_USER' ($TARGET_HOME)"
else
  TARGET_USER=$(whoami)
  TARGET_HOME="$HOME"
  echo "Detected normal user execution: configuring for '$TARGET_USER'"
fi

WAYBAR_DEST="$TARGET_HOME/.config/waybar"

# Ensure dependencies exist
echo "📦 Installing Waybar dependencies..."
sudo xbps-install -Sy --yes waybar brightnessctl wl-clipboard wireplumber \
  power-profiles-daemon network-manager-applet || {
  echo "⚠️ Some Waybar dependencies failed to install. Continuing..."
}

# Backup old config if any
if [[ -d "$WAYBAR_DEST" ]]; then
  BACKUP_DIR="${WAYBAR_DEST}.bak-$(date +%Y%m%d-%H%M%S)"
  echo "📦 Backing up old Waybar config to: $BACKUP_DIR"
  mv "$WAYBAR_DEST" "$BACKUP_DIR"
fi

# Copy new config
echo "📁 Copying new Waybar configuration..."
mkdir -p "$WAYBAR_DEST"
cp -r "$CONFIG_SRC/"* "$WAYBAR_DEST/"

# Fix permissions
echo "🔧 Adjusting permissions..."
chown -R "$TARGET_USER":"$TARGET_USER" "$WAYBAR_DEST"

# Confirm assets exist
if [[ ! -f "$WAYBAR_DEST/config.jsonc" || ! -f "$WAYBAR_DEST/style.css" ]]; then
  echo "❌ Missing config or style file in $WAYBAR_DEST"
  exit 1
fi

# Ensure Waybar can start
echo "🚀 Testing Waybar binary..."
if ! command -v waybar >/dev/null 2>&1; then
  echo "❌ Waybar binary not found in PATH."
  exit 1
fi

echo "✅ Waybar configuration installed successfully for '$TARGET_USER'"
echo "📂 Config path: $WAYBAR_DEST"
echo "🪵 Log written to: $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
