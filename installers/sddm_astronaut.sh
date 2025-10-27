#!/bin/sh

set -e

echo "Installing SDDM Astronaut theme (manual method)..."

# Ensure all dependencies are installed (they must be available)
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

# Add the SDDM service symlink to /var/service/ (void linux runit)
if [ ! -L /var/service/sddm ]; then
    echo "Adding symlink for sddm service to /var/service/sddm"
    sudo ln -s /etc/sv/sddm /var/service/sddm
else
    echo "Symlink for sddm service already exists"
fi

echo "SDDM Astronaut theme successfully installed with Jake the Dog config!"
echo "Note: The SDDM service is linked but NOT enabled or started automatically."

