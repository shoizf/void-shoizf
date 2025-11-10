#!/usr/bin/env bash
# installers/grub.sh
# This script now installs and configures GRUB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

THEME_DIR="/boot/grub/themes/crossgrub"
THEME_REPO="https://github.com/krypciak/crossgrub.git"
WORKDIR=$(mktemp -d)

log_info() {
  echo -e "\u001B[0;36m[grub.sh] INFO:\u001B[0m $1"
}

log_error() {
  echo -e "\u001B[0;31m[grub.sh] ERROR:\u001B[0m $1" >&2
  exit 1
}

trap 'rm -rf "$WORKDIR"' EXIT

log_info "Starting GRUB & Boot setup..."
log_info "Requesting root permissions..."
if ! sudo -v; then
  log_error "Failed to obtain root permissions."
fi

log_info "Installing GRUB packages, Intel microcode, and os-prober..."
# We add grub-x86_64-efi and os-prober to ensure they are installed
sudo xbps-install -Sy -y intel-ucode grub-x86_64-efi os-prober

log_info "Cloning GRUB theme repository into temporary directory $WORKDIR..."
if ! git clone --depth 1 "$THEME_REPO" "$WORKDIR"; then
  log_error "Failed to clone GRUB theme repository."
fi

log_info "Installing GRUB theme files to $THEME_DIR..."
sudo rm -rf "$THEME_DIR"
sudo mkdir -p "$THEME_DIR"
sudo cp "$WORKDIR"/assets/*.png "$WORKDIR"/theme.txt "$WORKDIR"/*.pf2 "$THEME_DIR"/

log_info "Configuring /etc/default/grub to use theme..."
if ! sudo grep -q "^GRUB_THEME=" /etc/default/grub; then
  echo "GRUB_THEME="$THEME_DIR/theme.txt"" | sudo tee -a /etc/default/grub >/dev/null
else
  sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME="$THEME_DIR/theme.txt"|" /etc/default/grub
fi

log_info "Ensuring OS prober is enabled in /etc/default/grub..."
if ! sudo grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
  echo "GRUB_DISABLE_OS_PROBER=false" | sudo tee -a /etc/default/grub >/dev/null
else
  sudo sed -i "s|^GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|" /etc/default/grub
fi

# --- NEW COMMAND ---
log_info "Installing GRUB to EFI partition with bootloader-id 'shoizf'..."
# This installs the bootloader to the EFI partition with your custom ID.
if ! sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=shoizf --recheck; then
  log_error "Failed to install GRUB to EFI partition."
fi
# --- END NEW COMMAND ---

log_info "Generating GRUB configuration including OS prober..."
if ! sudo grub-mkconfig -o /boot/grub/grub.cfg; then
  log_error "Failed to generate GRUB configuration."
fi

log_info "✅ GRUB setup complete with OS prober enabled."
