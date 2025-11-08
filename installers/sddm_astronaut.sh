#!/bin/sh

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "Installing SDDM Astronaut theme (manual method)..."

echo "Installing dependencies..."
sudo xbps-install -Sy sddm qt6-svg qt6-virtualkeyboard qt6-multimedia

echo "Cloning sddm-astronaut-theme repository to /usr/share/sddm/themes/sddm-astronaut-theme ..."
sudo git clone -b master --depth 1 https://github.com/Keyitdev/sddm-astronaut-theme.git /usr/share/sddm/themes/sddm-astronaut-theme

echo "Copying fonts to /usr/share/fonts/ ..."
sudo cp -r /usr/share/sddm/themes/sddm-astronaut-theme/Fonts/* /usr/share/fonts/

echo "Configuring SDDM to use astronaut theme ..."
echo "[Theme]
Current=sddm-astronaut-theme" | sudo tee /etc/sddm.conf

echo "Configuring SDDM virtual keyboard ..."
sudo mkdir -p /etc/sddm.conf.d/
echo "[General]
InputMethod=qtvirtualkeyboard" | sudo tee /etc/sddm.conf.d/virtualkbd.conf

echo "Setting up 'jake_the_dog' variant in metadata.desktop ..."
sudo sed -i 's|^ConfigFile=.*|ConfigFile=Themes/jake_the_dog.conf|' /usr/share/sddm/themes/sddm-astronaut-theme/metadata.desktop

if [ ! -L /var/service/sddm ]; then
    echo "Adding symlink for sddm service to /var/service/sddm"
    sudo ln -s /etc/sv/sddm /var/service/sddm
else
    echo "Symlink for sddm service already exists"
fi

echo "SDDM Astronaut theme successfully installed with Jake the Dog config!"
echo "Note: The SDDM service is linked but NOT enabled or started automatically."
