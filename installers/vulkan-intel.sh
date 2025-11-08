#!/usr/bin/env bash
# installers/vulkan-intel.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "Installing Intel Vulkan packages..."
sudo xbps-install -Sy mesa-vulkan-intel mesa-vulkan-intel-32bit vulkan-loader vulkan-loader-32bit Vulkan-ValidationLayers Vulkan-Headers mesa-vulkan-lavapipe

if ! grep -q 'VK_ICD_FILENAMES' "$HOME/.bash_profile"; then
  echo 'export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json' >>"$HOME/.bash_profile"
  echo "Added VK_ICD_FILENAMES to .bash_profile"
fi

. "$HOME/.bash_profile"

echo "Intel Vulkan configuration complete."
