#!/bin/sh

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "Setting up Niri config..."

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

DEST_CONFIG="$TARGET_USER_HOME/.config/niri/config.kdl"
SRC_CONFIG="$REPO_ROOT/configs/niri/config.kdl"
SESSION_FILE="/usr/share/wayland-sessions/niri.desktop"

mkdir -p "$(dirname "$DEST_CONFIG")"

cp "$SRC_CONFIG" "$DEST_CONFIG"
echo "Copied config.kdl to $DEST_CONFIG"

echo "Creating $SESSION_FILE"
sudo tee "$SESSION_FILE" > /dev/null << EOF
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=dbus-run-session -- /usr/bin/niri
Type=WaylandSession
DesktopNames=niri
EOF

echo "Niri desktop session file created."
