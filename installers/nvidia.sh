#!/bin/sh
set -e

echo "Starting full NVIDIA driver setup..."

# --- 1. Get Kernel Version ---
# This gets the running kernel, e.g., "6.8.9_1"
KERNEL_VER=$(uname -r)
# This parses it to the package name, e.g., "linux6.8"
KERNEL_PKG=$(echo "$KERNEL_VER" | cut -d. -f1,2 | sed 's/\./_/' | sed 's/_[^0-9]*$//' | sed 's/_/./')

if [ -z "$KERNEL_PKG" ]; then
  echo "❌ [nvidia.sh] Could not determine kernel package from version: $KERNEL_VER"
  exit 1
fi
echo "Kernel package identified: $KERNEL_PKG"

# --- 2. Install Headers ---
echo "Installing kernel headers: ${KERNEL_PKG}-headers"
sudo xbps-install -Sy "${KERNEL_PKG}-headers"

# --- 3. Install NVIDIA Packages ---
echo "Installing NVIDIA packages..."
sudo xbps-install -Sy \
  nvidia \
  nvidia-dkms \
  nvidia-firmware \
  nvidia-gtklibs \
  nvidia-libs \
  nvidia-libs-32bit \
  nvidia-vaapi-driver

# --- 4. Blacklist Nouveau ---
echo "Blacklisting nouveau driver..."
cat <<EOF | sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null
blacklist nouveau
options nouveau modeset=0
EOF

# --- 5. Regenerate Initramfs (VITAL) ---
echo "Regenerating initramfs for kernel: $KERNEL_PKG"
sudo xbps-reconfigure -f "$KERNEL_PKG"

echo "✅ NVIDIA installation and configuration complete."
echo "   A reboot is required for changes to take effect."
