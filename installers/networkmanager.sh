#!/bin/sh
set -e

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "Installing NetworkManager and related packages..."
sudo xbps-install -Sy NetworkManager networkmanager-dmenu nm-tray

echo "Configuring NetworkManager to use internal DHCP..."
CONF_DIR="/etc/NetworkManager/conf.d"
CONF_FILE="$CONF_DIR/90-internal-dhcp.conf"

sudo mkdir -p "$CONF_DIR"

cat <<EOF | sudo tee "$CONF_FILE" >/dev/null
[main]
dhcp=internal
EOF

echo "Disabling dhcpcd and wpa_supplicant for next boot..."
if [ -L /var/service/dhcpcd ]; then
  sudo rm /var/service/dhcpcd
fi

if [ -L /var/service/wpa_supplicant ]; then
  sudo rm /var/service/wpa_supplicant
fi

if [ -f /etc/resolv.conf ]; then
  sudo mv /etc/resolv.conf /etc/resolv.conf.old
fi

echo "NetworkManager handoff and configuration complete."
