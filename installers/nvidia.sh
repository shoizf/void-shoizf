#!/usr/bin/env bash
# installers/nvidia.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

log_info() {
  echo -e "\u001B[0;36m[nvidia.sh] INFO:\u001B[0m $1"
}

log_error() {
  echo -e "\u001B[0;31m[nvidia.sh] ERROR:\u001B[0m $1" >&2
  exit 1
}

log_info "Starting NVIDIA driver installation..."

# --- 1. Detect Kernel ---
KERNEL_VER=$(uname -r)
KERNEL_PKG_BASE=$(echo "$KERNEL_VER" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
if [[ -z "$KERNEL_PKG_BASE" ]]; then
  log_error "Could not parse kernel version from uname output: $KERNEL_VER"
fi
KERNEL_PKG="linux${KERNEL_PKG_BASE}"
log_info "Detected kernel package base name: $KERNEL_PKG"

# --- 2. Install Packages ---
log_info "Installing kernel headers: ${KERNEL_PKG}-headers"
sudo xbps-install -Sy -y "${KERNEL_PKG}-headers"

log_info "Installing NVIDIA driver packages..."
sudo xbps-install -Sy -y \
  nvidia \
  nvidia-dkms \
  nvidia-firmware \
  nvidia-gtklibs \
  nvidia-libs \
  nvidia-libs-32bit \
  nvidia-vaapi-driver

# --- 3. Blacklist Nouveau ---
log_info "Blacklisting nouveau driver..."
sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

# --- 4. Configure GRUB (Robustly) ---
log_info "Enabling NVIDIA DRM kernel mode setting for Wayland..."

GRUB_FILE="/etc/default/grub"
GRUB_PARAM="nvidia-drm.modeset=1"

# Step 4a: Clean up any and all existing entries to prevent duplicates
# This removes "nvidia-drm.modeset=1" and " nvidia-drm.modeset=1"
log_info "Cleaning old DRM entries from $GRUB_FILE..."
sudo sed -i 's/ nvidia-drm.modeset=1//g' "$GRUB_FILE"
sudo sed -i 's/nvidia-drm.modeset=1//g' "$GRUB_FILE"

# Step 4b: Add the parameter back cleanly one time
log_info "Adding clean DRM entry to $GRUB_FILE..."
sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\\(.*\\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 $GRUB_PARAM\"/" "$GRUB_FILE"

# Step 4c: Update the GRUB config to apply changes
log_info "Updating GRUB configuration..."
if ! sudo grub-mkconfig -o /boot/grub/grub.cfg; then
  log_error "Failed to update GRUB configuration!"
fi

# --- 5. Regenerate Initramfs ---
log_info "Regenerating initramfs for kernel: $KERNEL_PKG"
# This forces dkms to build the new NVIDIA modules
if ! sudo xbps-reconfigure -f "$KERNEL_PKG"; then
  log_error "Failed to regenerate initramfs. NVIDIA modules may not be loaded on boot."
fi

log_info "✅ NVIDIA installation complete. Reboot recommended."
