#!/bin/bash
set -euo pipefail

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
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

log_info "Starting full GRUB & Boot setup..."

log_info "Root permissions are required for boot tasks."
sudo -v || log_error "Failed to obtain root permissions."
log_info "Root permissions acquired."

log_info "Installing Intel CPU microcode..."
sudo xbps-install -Sy intel-ucode

log_info "Cloning theme repository into $WORKDIR..."
git clone --depth 1 "$THEME_REPO" "$WORKDIR"

log_info "Installing theme files to $THEME_DIR..."
sudo rm -rf "$THEME_DIR"
sudo mkdir -p "$THEME_DIR"
sudo cp "$WORKDIR"/assets/*.png "$WORKDIR"/theme.txt "$WORKDIR"/*.pf2 "$THEME_DIR"/
if [ $? -ne 0 ]; then
  log_error "Failed to copy theme files to $THEME_DIR."
fi

log_info "Updating /etc/default/grub configuration..."
if ! sudo grep -q "^GRUB_THEME=" /etc/default/grub; then
  echo "GRUB_THEME="$THEME_DIR/theme.txt"" | sudo tee -a /etc/default/grub >/dev/null
else
  sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME="$THEME_DIR/theme.txt"|" /etc/default/grub
fi

log_info "Regenerating GRUB configuration (grub-mkconfig)..."
sudo grub-mkconfig -o /boot/grub/grub.cfg
if [ $? -ne 0 ]; then
  log_error "grub-mkconfig failed."
fi

log_info "✅ GRUB theme, Intel ucode, and Windows detection complete!"
