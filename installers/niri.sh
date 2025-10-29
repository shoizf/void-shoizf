#!/bin/sh

set -e

SRC_CONFIG="$HOME/.local/share/void-shoizf/configs/niri/config.kdl"
DEST_CONFIG="$HOME/.config/niri/config.kdl"
SESSION_FILE="/usr/share/wayland-sessions/niri.desktop"

echo "Setting up Niri config..."

# Create destination config dir if it doesn't exist
mkdir -p "$(dirname "$DEST_CONFIG")"

# Copy config.kdl
cp "$SRC_CONFIG" "$DEST_CONFIG"
echo "Copied config.kdl to $DEST_CONFIG"

# Create or overwrite niri.desktop
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


