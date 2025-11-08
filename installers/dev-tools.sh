#!/usr/bin/env bash
# installers/dev-tools.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

echo "Configuring tools for user: $TARGET_USER ($TARGET_USER_HOME)"

NVIM_CONFIG_DIR="$TARGET_USER_HOME/.config/nvim"
if [ -d "$NVIM_CONFIG_DIR" ]; then
  mv "$NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR.bak-$(date +%Y%m%d-%H%M%S)"
fi

echo "Cloning LazyVim starter..."
if git clone https://github.com/LazyVim/starter "$NVIM_CONFIG_DIR"; then
  rm -rf "$NVIM_CONFIG_DIR/.git"
else
  echo "❌ [dev-tools.sh] Failed to clone LazyVim starter."
  exit 1
fi

echo "Installing Oh My Tmux..."
if curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash; then
  touch "$TARGET_USER_HOME/.tmux.conf.local"
else
  echo "❌ [dev-tools.sh] Failed to install Oh My Tmux."
  exit 1
fi

echo "✅ Developer tools configured successfully."
