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

echo "Installing Oh My Tmux (non-interactive)..."

# Define paths
TMUX_DIR="$TARGET_USER_HOME/.tmux"
REPO_URL="https://github.com/gpakosz/.tmux.git"

# 1. Clone or update the repo
if [ -d "$TMUX_DIR" ]; then
  echo "Updating existing Oh My Tmux repo..."
  if ! git -C "$TMUX_DIR" pull; then
    echo "Git pull failed, removing and re-cloning."
    rm -rf "$TMUX_DIR"
    git clone --depth=1 "$REPO_URL" "$TMUX_DIR"
  fi
else
  echo "Cloning Oh My Tmux repo..."
  git clone --depth=1 "$REPO_URL" "$TMUX_DIR"
fi

# 2. Create the main symlink
# 'ln -sfn' forces the creation of the symlink.
echo "Creating symlink for .tmux.conf..."
ln -sfn "$TMUX_DIR/.tmux.conf" "$TARGET_USER_HOME/.tmux.conf"

# 3. Create the local config file
echo "Creating .tmux.conf.local..."
touch "$TARGET_USER_HOME/.tmux.conf.local"

echo "✅ Oh My Tmux installed."

echo "✅ Developer tools configured successfully."
