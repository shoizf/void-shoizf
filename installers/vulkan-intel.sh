#!/bin/sh

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

# Set Vulkan to use Intel GPU by default
if ! grep -q 'VK_ICD_FILENAMES' "$HOME/.bash_profile"; then
    echo 'export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json' >> "$HOME/.bash_profile"
    echo "Added VK_ICD_FILENAMES environment variable to .bash_profile"
else
    echo "VK_ICD_FILENAMES already set in .bash_profile"
fi

. "$HOME/.bash_profile"

echo "Intel Vulkan configuration complete."

