#!/bin/sh
set -e

log_info() {
  echo -e "\033[0;36m[networkmanager]\033[0m $1"
}

log_error() {
  echo -e "\033[0;31m[networkmanager ERROR]\033[0m $1" >&2
  exit 1
}

# --- 1. Install Packages ---
log_info "Installing NetworkManager and related packages..."
# This command uses the live, parent-script dhcpcd connection
sudo xbps-install -Sy NetworkManager networkmanager-dmenu nm-tray

# --- 2. Configure NetworkManager ---
log_info "Configuring NetworkManager to use internal DHCP..."
CONF_DIR="/etc/NetworkManager/conf.d"
CONF_FILE="$CONF_DIR/90-internal-dhcp.conf"

sudo mkdir -p "$CONF_DIR"

# This forces NetworkManager to use its internal DHCP client
# and prevents it from ever using the 'dhcpcd' binary.
cat <<EOF | sudo tee "$CONF_FILE" >/dev/null
[main]
dhcp=internal
EOF

# --- 3. Handoff: Disable Old Services ---
# We are *not* stopping the live service (sv down), which would
# kill the installer. We are just removing the symlinks so
# they do not start on the next boot.

log_info "Disabling dhcpcd service from next boot..."
if [ -L /var/service/dhcpcd ]; then
  sudo rm /var/service/dhcpcd
fi

log_info "Disabling wpa_supplicant service from next boot..."
if [ -L /var/service/wpa_supplicant ]; then
  sudo rm /var/service/wpa_supplicant
fi

# --- 4. Handoff: Remove Stale Config ---
log_info "Removing stale dhcpcd resolv.conf..."
if [ -f /etc/resolv.conf ]; then
  # We move the file just to be safe
  sudo mv /etc/resolv.conf /etc/resolv.conf.old
fi

log_info "NetworkManager handoff and configuration complete."
# The parent install.sh will handle enabling the NetworkManager service
# for the next boot.
