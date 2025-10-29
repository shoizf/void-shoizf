#!/bin/sh

echo "Starting NVIDIA driver and audio packages installation..."

sudo xbps-install -Sy \
  nvidia \
  nvidia-dkms \
  nvidia-firmware \
  nvidia-gtklibs \
  nvidia-libs \
  nvidia-libs-32bit \
  nvidia-vaapi-driver \
  pulseaudio \
  pulseaudio-utils \
  pamixer \
  libpulseaudio \
  libpulseaudio-32bit \
  pipewire \
  alsa-pipewire \
  wireplumber

echo "NVIDIA drivers and audio packages installed."

echo "NVIDIA installation and configuration complete."

