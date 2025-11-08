#!/usr/bin/env bash
# installers/intel.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "Installing Intel GPU and Xorg packages..."
sudo xbps-install -Sy mesa-dri mesa-dri-32bit mesa-demos xf86-video-intel

echo "Intel GPU setup complete."
