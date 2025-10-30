#!/bin/sh

# Installer for developer tools: LazyVim and Oh My Tmux
# This script should be run as the regular user, not root.

# --- Determine Target User and Home Directory ---
# Use arguments passed from parent script, fall back to logname/whoami
TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_USER_HOME" ]; then
  echo "❌ [dev-tools.sh] Could not determine target user or home directory."
  exit 1
fi
echo "Configuring tools for user: $TARGET_USER ($TARGET_USER_HOME)"

# --- 1. Install LazyVim ---
echo "Configuring LazyVim..."
NVIM_CONFIG_DIR="$TARGET_USER_HOME/.config/nvim"

# Safety Check: Back up existing config if it exists
if [ -d "$NVIM_CONFIG_DIR" ]; then
  echo "Found existing Nvim config at $NVIM_CONFIG_DIR. Backing it up..."
  # Create a timestamped backup
  mv "$NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR.bak-$(date +%Y%m%d-%H%M%S)"
  if [ $? -ne 0 ]; then
    echo "❌ [dev-tools.sh] Failed to back up existing nvim config. Aborting LazyVim setup."
    exit 1
  fi
fi

# Clone the LazyVim starter (using the user's provided command)
echo "Cloning LazyVim starter..."
if git clone https://github.com/LazyVim/starter "$NVIM_CONFIG_DIR"; then
  # Remove the .git directory (using the user's provided command)
  rm -rf "$NVIM_CONFIG_DIR/.git"
  echo "✅ LazyVim configuration finished."
else
  echo "❌ [dev-tools.sh] Failed to clone LazyVim starter."
  exit 1
fi

# --- 2. Install Oh My Tmux ---
echo "Configuring Oh My Tmux..."
# We need to run this as the target user. Since this script *is* the target user, we can pipe to bash.
# Using the user's provided command:
if curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash; then
  # Create the local config file for user customizations
  touch "$TARGET_USER_HOME/.tmux.conf.local"
  echo "✅ Oh My Tmux configuration finished."
  echo "    -> User configuration can be added to ~/.tmux.conf.local"
else
  echo "❌ [dev-tools.sh] Failed to install Oh My Tmux."
  exit 1
fi

echo "✅ Developer tools (LazyVim, Tmux) configured successfully."
