#!/bin/bash
# Exit immediately if any command fails
set -e

# --- Configuration ---
THEME_DIR="/boot/grub/themes/crossgrub"
THEME_REPO="https://github.com/krypciak/crossgrub.git"
# Use mktemp for a clean, safe temporary directory
WORKDIR=$(mktemp -d)

# --- Helper Functions ---
log_info() {
  echo -e "\033[0;36m[grub.sh] INFO:\033[0m $1"
}
log_error() {
  echo -e "\033[0;31m[grub.sh] ERROR:\033[0m $1" >&2
  exit 1
}
# --- Trap to ensure cleanup on exit ---
trap 'rm -rf "$WORKDIR"' EXIT

# --- Main Script ---
log_info "Starting full GRUB & Boot setup..."

# 1. Prompt for sudo password upfront
log_info "Root permissions are required for boot tasks."
sudo -v || log_error "Failed to obtain root permissions."
log_info "Root permissions acquired."

# 2. Install Intel CPU Microcode
log_info "Installing Intel CPU microcode..."
sudo xbps-install -Sy intel-ucode

# 3. Clone the theme repository
log_info "Cloning theme repository into $WORKDIR..."
git clone --depth 1 "$THEME_REPO" "$WORKDIR"

# 4. Install the theme to /boot
log_info "Installing theme files to $THEME_DIR..."
sudo rm -rf "$THEME_DIR"
sudo mkdir -p "$THEME_DIR"
sudo cp "$WORKDIR"/assets/*.png "$WORKDIR"/theme.txt "$WORKDIR"/*.pf2 "$THEME_DIR"/
if [ $? -ne 0 ]; then
  log_error "Failed to copy theme files to $THEME_DIR."
fi

# 5. Configure GRUB theme
log_info "Updating /etc/default/grub configuration..."
if ! sudo grep -q "^GRUB_THEME=" /etc/default/grub; then
  echo "GRUB_THEME=\"$THEME_DIR/theme.txt\"" | sudo tee -a /etc/default/grub >/dev/null
else
  sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DIR/theme.txt\"|" /etc/default/grub
fi

# 6. Regenerate the final GRUB config (This will also find Windows)
log_info "Regenerating GRUB configuration (grub-mkconfig)..."
sudo grub-mkconfig -o /boot/grub/grub.cfg
if [ $? -ne 0 ]; then
  log_error "grub-mkconfig failed."
fi

log_info "✅ GRUB theme, Intel ucode, and Windows detection complete!"
# The 'trap' will automatically clean up $WORKDIR on exit
