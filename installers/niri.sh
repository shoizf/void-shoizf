#!/usr/bin/env bash
# installers/niri.sh — install Niri session file and copy config.kdl

set -euo pipefail

LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
MASTER_LOG="$LOG_DIR/master-install.log"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE" >>"$MASTER_LOG"
}

log "▶ niri.sh starting"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_CONFIG="$REPO_ROOT/configs/niri/config.kdl"
DEST_CONFIG="$TARGET_USER_HOME/.config/niri/config.kdl"
SESSION_FILE="/usr/share/wayland-sessions/niri.desktop"

mkdir -p "$(dirname "$DEST_CONFIG")"
cp -f "$SRC_CONFIG" "$DEST_CONFIG"
chown "$TARGET_USER":"$TARGET_USER" "$DEST_CONFIG" || true
log "OK Copied config.kdl -> $DEST_CONFIG"

# Install session file (requires sudo)
sudo tee "$SESSION_FILE" >/dev/null <<EOF
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=dbus-run-session -- /usr/bin/niri
Type=WaylandSession
DesktopNames=niri
EOF

log "OK Niri session file created: $SESSION_FILE"
log "✅ niri.sh finished"
