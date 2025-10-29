#!/bin/sh

echo "Installing Intel GPU, audio, and Xorg related packages..."

sudo xbps-install -Sy \
  mesa-dri \
  mesa-dri-32bit \
  mesa-demos \
  xf86-video-intel \
  pulseaudio \
  pulseaudio-utils \
  pamixer \
  libpulseaudio \
  libpulseaudio-32bit \
  pipewire \
  alsa-pipewire \
  wireplumber

echo "Intel GPU and audio packages installed."

echo "Intel iGPU setup complete."

