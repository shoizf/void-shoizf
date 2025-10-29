#!/bin/sh

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
# Note: nvidia-firmware is handled by the nvidia installer script
# Note: wifi/other firmware are likely deps or handled elsewhere

# Use sudo locally within this script for package installation
# The -S flag ensures packages are installed if missing, -y confirms.
sudo xbps-install -Sy $AUDIO_PACKAGES

if [ $? -eq 0 ]; then
  echo "✅ Audio packages installed successfully!"
else
  echo "❌ Audio package installation failed! Check the output for errors."
  exit 1 # Exit if audio packages fail, as it's critical
fi

# Configuration steps (like ALSA conf links) remain commented out for now.
# If uncommented later, ensure 'sudo' is added before mkdir/ln.
echo "Configuring ALSA to use PipeWire..."
sudo mkdir -p /etc/alsa/conf.d
sudo ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/

# Note: This script only handles installation.
# The actual startup of pipewire/wireplumber should be handled
# by the Niri configuration (config.kdl) using spawn-at-startup.
# Ensure pipewire-pulse is started if needed (often automatic).

echo "Audio integration script finished."

# Suggest a reboot after firmware installation
echo "IMPORTANT: A reboot is recommended after installing firmware packages."
