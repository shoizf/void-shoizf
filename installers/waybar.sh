#!/usr/bin/env bash
# installers/waybar.sh — copy waybar config and ensure dependencies

set -euo pipefail

LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
MASTER_LOG="$LOG_DIR/master-install.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" | tee -a "$LOG_FILE" >>"$MASTER_LOG"; }

log "▶ waybar.sh starting"

TARGET_USER=${1:-$(whoami)}
TARGET_HOME=${2:-$HOME}
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SRC="$REPO_ROOT/configs/waybar"
WAYBAR_DEST="$TARGET_HOME/.config/waybar"

log "INFO Installing Waybar deps"
sudo xbps-install -Sy --yes waybar brightnessctl wl-clipboard wireplumber power-profiles-daemon network-manager-applet || log "WARN waybar deps install had issues"

if [ -d "$WAYBAR_DEST" ]; then
  BACKUP_DIR="${WAYBAR_DEST}.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$WAYBAR_DEST" "$BACKUP_DIR" || log "WARN failed to backup old waybar config"
  log "OK backed up old config to $BACKUP_DIR"
fi

mkdir -p "$WAYBAR_DEST"
cp -r "$CONFIG_SRC/"* "$WAYBAR_DEST/"
chown -R "$TARGET_USER":"$TARGET_USER" "$WAYBAR_DEST" || true

if [ ! -f "$WAYBAR_DEST/config.jsonc" ]; then
  log "ERROR Waybar config missing after copy"
  exit 1
fi

if ! command -v waybar >/dev/null 2>&1; then
  log "WARN waybar binary not found — please ensure package installed"
fi

log "✅ waybar.sh finished"
