#!/bin/sh

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Installer for developer tools

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_USER_HOME" ]; then
  echo "❌ [dev-tools.sh] Could not determine target user or home directory."
  exit 1
fi
echo "Configuring tools for user: $TARGET_USER ($TARGET_USER_HOME)"

echo "Configuring LazyVim..."
NVIM_CONFIG_DIR="$TARGET_USER_HOME/.config/nvim"

if [ -d "$NVIM_CONFIG_DIR" ]; then
  echo "Found existing Nvim config at $NVIM_CONFIG_DIR. Backing it up..."
  mv "$NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR.bak-$(date +%Y%m%d-%H%M%S)"
  if [ $? -ne 0 ]; then
    echo "❌ [dev-tools.sh] Failed to back up existing nvim config. Aborting LazyVim setup."
    exit 1
  fi
fi

echo "Cloning LazyVim starter..."
if git clone https://github.com/LazyVim/starter "$NVIM_CONFIG_DIR"; then
  rm -rf "$NVIM_CONFIG_DIR/.git"
  echo "✅ LazyVim configuration finished."
else
  echo "❌ [dev-tools.sh] Failed to clone LazyVim starter."
  exit 1
fi

echo "Configuring Oh My Tmux..."
if curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash; then
  touch "$TARGET_USER_HOME/.tmux.conf.local"
  echo "✅ Oh My Tmux configuration finished."
  echo "    -> User configuration can be added to ~/.tmux.conf.local"
else
  echo "❌ [dev-tools.sh] Failed to install Oh My Tmux."
  exit 1
fi

echo "✅ Developer tools (LazyVim, Tmux) configured successfully."
