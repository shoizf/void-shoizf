#!/bin/bash
# Exit immediately if any command fails
set -e

# --- Configuration ---
THEME_DIR="/boot/grub/themes/crossgrub"
THEME_REPO="https://github.com/krypciak/crossgrub.git"
WORKDIR="$HOME/.local/share/crossgrub" # Temporary clone location

# --- Helper Functions ---
log_info() {
    # Using cyan color for info messages
    echo -e "\033[0;36mINFO:\033[0m $1"
}

log_error() {
    # Using red color for error messages
    echo -e "\033[0;31mERROR:\033[0m $1" >&2
    exit 1
}

# --- Pre-run Checks ---
# Check if git is installed
if ! command -v git &> /dev/null; then
    log_error "git is not installed. Please install it to continue."
fi

# --- Main Script ---
log_info "Starting Crossgrub theme installation..."

# 1. Prompt for sudo password upfront (Condition 2)
# This validates the user's sudo timestamp, asking for a password only if needed.
log_info "Root permissions are required to write to /boot and /etc."
sudo -v
if [ $? -ne 0 ]; then
    log_error "Failed to obtain root permissions."
fi
log_info "Root permissions acquired."

# 2. Clone the theme repository (as user - Condition 1 & 3)
# This happens in the user's home directory, so no sudo is needed.
log_info "Cloning theme repository into $WORKDIR..."
# Create the parent directory (e.g., ~/.local/share) if it doesn't exist
mkdir -p "$(dirname "$WORKDIR")"
# Remove any old clone and re-clone for a fresh install
rm -rf "$WORKDIR"
git clone --depth 1 "$THEME_REPO" "$WORKDIR"

# 3. Install the theme to /boot (with sudo)
log_info "Installing theme files to $THEME_DIR..."
# Clean up any old broken install and create a fresh directory
sudo rm -rf "$THEME_DIR"
sudo mkdir -p "$THEME_DIR"

# *** THIS IS THE FIX ***
# Copy files *out* of `assets` and into the theme directory, "flattening"
# the structure to match what theme.txt expects.
log_info "Copying and flattening theme files..."
sudo cp "$WORKDIR"/assets/*.png "$WORKDIR"/theme.txt "$WORKDIR"/*.pf2 "$THEME_DIR"/
if [ $? -ne 0 ]; then
    log_error "Failed to copy theme files to $THEME_DIR."
fi

# 4. Configure GRUB (with sudo)
log_info "Updating /etc/default/grub configuration..."
# Check if GRUB_THEME line already exists
if ! sudo grep -q "^GRUB_THEME=" /etc/default/grub; then
    log_info "Adding GRUB_THEME entry..."
    # Add the line if it doesn't exist
    echo "GRUB_THEME=\"$THEME_DIR/theme.txt\"" | sudo tee -a /etc/default/grub > /dev/null
else
    log_info "Updating existing GRUB_THEME entry..."
    # Update the line if it already exists, ensuring quotes
    sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DIR/theme.txt\"|" /etc/default/grub
fi

# 5. Regenerate the final GRUB config (with sudo)
log_info "Regenerating GRUB configuration (grub-mkconfig)..."
sudo grub-mkconfig -o /boot/grub/grub.cfg
if [ $? -ne 0 ]; then
    log_error "grub-mkconfig failed."
fi

# 6. Cleanup (as user)
log_info "Cleaning up temporary clone..."
rm -rf "$WORKDIR"

log_info "Crossgrub theme installed successfully! ✨"
