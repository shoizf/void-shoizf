#!/usr/bin/env bash
# installers/nvidia.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

KERNEL_VER=$(uname -r)

# Use sed instead of grep -P to extract major.minor version safely
KERNEL_PKG_BASE=$(echo "$KERNEL_VER" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
if [[ -z "$KERNEL_PKG_BASE" ]]; then
  echo "❌ Could not parse kernel version from uname output: $KERNEL_VER"
  exit 1
fi
KERNEL_PKG="linux${KERNEL_PKG_BASE}"

echo "🧩 Detected kernel package base name: $KERNEL_PKG"

echo "📦 Installing kernel headers: ${KERNEL_PKG}-headers"
sudo xbps-install -Sy "${KERNEL_PKG}-headers"

echo "📦 Installing NVIDIA driver packages..."
sudo xbps-install -Sy \
  nvidia \
  nvidia-dkms \
  nvidia-firmware \
  nvidia-gtklibs \
  nvidia-libs \
  nvidia-libs-32bit \
  nvidia-vaapi-driver

echo "🚫 Blacklisting nouveau driver..."
sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

echo "🔁 Regenerating initramfs for kernel: $KERNEL_PKG"
sudo xbps-reconfigure -f "$KERNEL_PKG"

echo "✅ NVIDIA installation complete. Reboot recommended."
