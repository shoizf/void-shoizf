#!/bin/sh

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "Starting Intel Vulkan packages installation..."

sudo xbps-install -Sy \
  mesa-vulkan-intel \
  mesa-vulkan-intel-32bit \
  vulkan-loader \
  vulkan-loader-32bit \
  Vulkan-ValidationLayers \
  Vulkan-Headers \
  mesa-vulkan-lavapipe

echo "Intel Vulkan packages installed."

if ! grep -q 'VK_ICD_FILENAMES' "$HOME/.bash_profile"; then
    echo 'export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json' >> "$HOME/.bash_profile"
    echo "Added VK_ICD_FILENAMES environment variable to .bash_profile"
else
    echo "VK_ICD_FILENAMES already set in .bash_profile"
fi

. "$HOME/.bash_profile"

echo "Intel Vulkan configuration complete."
