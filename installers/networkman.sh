#!/usr/bin/env bash
# installers/networkman.sh — NetworkManager setup for Void Linux
# Author: shoizf
# Description: Configures NetworkManager for both hardware and VM (NAT) environments.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "🌐 Installing NetworkManager packages..."
sudo xbps-install -Sy NetworkManager networkmanager-dmenu nm-tray

# Detect if running in a virtualized environment
if systemd-detect-virt >/dev/null 2>&1; then
  echo "💡 Virtual machine detected — configuring minimal Ethernet/NAT setup."
else
  echo "🛰️ Real hardware detected — enabling full NetworkManager features."
fi

# Configure DHCP to use internal plugin (safe for NAT and Wi-Fi)
CONF_DIR="/etc/NetworkManager/conf.d"
CONF_FILE="$CONF_DIR/90-internal-dhcp.conf"
sudo mkdir -p "$CONF_DIR"

cat <<EOF | sudo tee "$CONF_FILE" >/dev/null
[main]
dhcp=internal
EOF

# Remove conflicting services if active
for svc in dhcpcd wpa_supplicant; do
  if [ -L "/var/service/$svc" ]; then
    echo "⚙️  Removing conflicting service link: $svc"
    sudo rm "/var/service/$svc"
  fi
done

# Backup resolv.conf safely (only once)
if [ -f /etc/resolv.conf ] && [ ! -f /etc/resolv.conf.old ]; then
  sudo mv /etc/resolv.conf /etc/resolv.conf.old
fi

# Enable NetworkManager (runit)
if [ ! -L /var/service/NetworkManager ]; then
  echo "🔌 Enabling NetworkManager service..."
  sudo ln -s /etc/sv/NetworkManager /var/service
fi

echo "✅ NetworkManager configured successfully."
