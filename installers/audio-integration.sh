#!/usr/bin/env bash
# installers/audio-integration.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

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

sudo xbps-install -Sy $AUDIO_PACKAGES || echo "⚠️ Audio packages may have issues."

echo "Configuring ALSA to use PipeWire..."
sudo mkdir -p /etc/alsa/conf.d
sudo ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/

echo "Audio integration script finished."
echo "IMPORTANT: A reboot is recommended after installing firmware packages."
