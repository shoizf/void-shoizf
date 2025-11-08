#!/bin/sh

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Audio Integration Script for void-shoizf setup
# Installs PipeWire, WirePlumber, ALSA compatibility, and necessary firmware.

echo "Installing Audio components (PipeWire, WirePlumber, Firmware)..."

AUDIO_PACKAGES="
pipewire
wireplumber
wireplumber-elogind
libpipewire
alsa-pipewire
libspa-alsa
alsa-lib
alsa-utils
alsa-ucm-conf
alsa-plugins-pulseaudio
sof-firmware
linux-firmware
linux-firmware-intel
"

sudo xbps-install -Sy $AUDIO_PACKAGES

if [ $? -eq 0 ]; then
  echo "✅ Audio packages installed successfully!"
else
  echo "❌ Audio package installation failed! Check the output for errors."
  exit 1
fi

echo "Configuring ALSA to use PipeWire..."
sudo mkdir -p /etc/alsa/conf.d
sudo ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/

echo "Audio integration script finished."
echo "IMPORTANT: A reboot is recommended after installing firmware packages."
