#!/usr/bin/env bash
# installers/sddm_astronaut.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

echo "Installing SDDM Astronaut theme..."

sudo xbps-install -Sy sddm qt6-svg qt6-virtualkeyboard qt6-multimedia

if [ -d /usr/share/sddm/themes/sddm-astronaut-theme ]; then
  echo "Theme directory exists, skipping clone."
else
  sudo git clone -b master --depth 1 https://github.com/Keyitdev/sddm-astronaut-theme.git /usr/share/sddm/themes/sddm-astronaut-theme
fi

sudo cp -r /usr/share/sddm/themes/sddm-astronaut-theme/Fonts/* /usr/share/fonts/

echo "[Theme]
Current=sddm-astronaut-theme" | sudo tee /etc/sddm.conf

sudo mkdir -p /etc/sddm.conf.d/
echo "[General]
InputMethod=qtvirtualkeyboard" | sudo tee /etc/sddm.conf.d/virtualkbd.conf

sudo sed -i 's|^ConfigFile=.*|ConfigFile=Themes/jake_the_dog.conf|' /usr/share/sddm/themes/sddm-astronaut-theme/metadata.desktop

if [ ! -L /var/service/sddm ]; then
  sudo ln -s /etc/sv/sddm /var/service/sddm
fi

echo "SDDM Astronaut theme installed."
