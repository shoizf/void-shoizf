#!/usr/bin/env bash
# installers/nvidia.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

KERNEL_VER=$(uname -r)
KERNEL_PKG=$(echo "$KERNEL_VER" | cut -d. -f1,2 | sed 's/./_/' | sed 's/_[^0-9]*$//' | sed 's/_/./')

if [ -z "$KERNEL_PKG" ]; then
  echo "❌ Could not determine kernel package."
  exit 1
fi

echo "Installing kernel headers: ${KERNEL_PKG}-headers"
sudo xbps-install -Sy "${KERNEL_PKG}-headers"

echo "Installing NVIDIA packages..."
sudo xbps-install -Sy nvidia nvidia-dkms nvidia-firmware nvidia-gtklibs nvidia-libs nvidia-libs-32bit nvidia-vaapi-driver

echo "Blacklisting nouveau driver..."
cat <<EOF | sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null
blacklist nouveau
options nouveau modeset=0
EOF

echo "Regenerating initramfs for kernel: $KERNEL_PKG"
sudo xbps-reconfigure -f "$KERNEL_PKG"

echo "NVIDIA installation complete. Reboot recommended."
