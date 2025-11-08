#!/bin/sh

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "Installing Intel GPU and Xorg related packages..."
sudo xbps-install -Sy mesa-dri mesa-dri-32bit mesa-demos xf86-video-intel

if [ $? -eq 0 ]; then
  echo "✅ Intel GPU packages installed successfully!"
else
  echo "❌ Intel GPU package installation failed!"
  exit 1
fi

echo "Intel iGPU setup complete."
