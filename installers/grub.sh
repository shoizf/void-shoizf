#!/bin/bash
set -e
THEME_DIR="/boot/grub/themes/crossgrub"
THEME_REPO="https://github.com/krypciak/crossgrub.git"
WORKDIR="/tmp/crossgrub"

if [ "$(whoami)" != "root" ]; then
  echo "This script must be run as root"
  exit 1
fi

# Clone or pull latest theme
rm -rf "$WORKDIR"
git clone "$THEME_REPO" "$WORKDIR"

# Install theme files
mkdir -p /boot/grub/themes
rm -rf "$THEME_DIR"
cp -r "$WORKDIR" "$THEME_DIR"

# Update GRUB_THEME entry
if ! grep -q "^GRUB_THEME=" /etc/default/grub; then
  echo "GRUB_THEME=$THEME_DIR/theme.txt" >> /etc/default/grub
else
  sed -i "s|^GRUB_THEME=.*|GRUB_THEME=$THEME_DIR/theme.txt|" /etc/default/grub
fi

# Update GRUB config
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "Crossgrub theme installed successfully"

