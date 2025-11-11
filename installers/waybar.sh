#!/usr/bin/env bash
# installers/waybar.sh

set -euo pipefail

# --- Setup paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_SRC="$REPO_ROOT/configs/waybar"

# Use the same logging path as main install.sh
LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/waybar-install.log"

# Redirect all output to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧱 Starting Waybar setup..."
echo "Log file: $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Determine user and home directory ---
TARGET_USER=${1:-$(whoami)}
TARGET_HOME=${2:-$HOME}

WAYBAR_DEST="$TARGET_HOME/.config/waybar"

echo "📂 Installing for user: $TARGET_USER"
echo "🏠 Target home: $TARGET_HOME"
echo "📁 Config destination: $WAYBAR_DEST"

# --- Ensure dependencies ---
echo "📦 Installing Waybar dependencies..."
sudo xbps-install -Sy --yes waybar brightnessctl wl-clipboard wireplumber \
  power-profiles-daemon network-manager-applet || {
  echo "⚠️ Some Waybar dependencies failed to install. Continuing..."
}

# --- Backup existing config ---
if [[ -d "$WAYBAR_DEST" ]]; then
  BACKUP_DIR="${WAYBAR_DEST}.bak-$(date +%Y%m%d-%H%M%S)"
  echo "📦 Backing up existing config to: $BACKUP_DIR"
  mv "$WAYBAR_DEST" "$BACKUP_DIR"
fi

# --- Copy new config ---
echo "📁 Copying Waybar configuration from $CONFIG_SRC ..."
mkdir -p "$WAYBAR_DEST"
cp -r "$CONFIG_SRC/"* "$WAYBAR_DEST/"

# --- Fix permissions ---
echo "🔧 Fixing ownership and permissions..."
chown -R "$TARGET_USER":"$TARGET_USER" "$WAYBAR_DEST"

# --- Verify installation ---
if [[ ! -f "$WAYBAR_DEST/config.jsonc" || ! -f "$WAYBAR_DEST/style.css" ]]; then
  echo "❌ Missing Waybar config files. Check source at $CONFIG_SRC"
  exit 1
fi

if ! command -v waybar >/dev/null 2>&1; then
  echo "❌ Waybar binary not found in PATH — installation likely failed."
  exit 1
fi

echo "✅ Waybar successfully configured for $TARGET_USER"
echo "🪵 Detailed log: $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
