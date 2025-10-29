#!/bin/sh
set -e

log_info() {
  echo -e "\033[0;36m[networkmanager]\033[0m $1"
}

log_error() {
  echo -e "\033[0;31m[networkmanager ERROR]\033[0m $1" >&2
  exit 1
}

log_info "Installing NetworkManager and related packages..."
sudo xbps-install -Sy NetworkManager networkmanager-dmenu nm-tray

log_info "Enabling NetworkManager service..."
if [ ! -L /var/service/NetworkManager ]; then
  sudo ln -s /etc/sv/NetworkManager /var/service/
fi

log_info "Starting NetworkManager service..."
sudo sv up NetworkManager

log_info "NetworkManager installation and service setup complete."
