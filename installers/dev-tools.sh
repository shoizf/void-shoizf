#!/usr/bin/env bash
# installers/dev-tools.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

echo "⚙️  Configuring developer tools for user: $TARGET_USER ($TARGET_USER_HOME)"

# ----------------------------------------------------------------------
# 1. LazyVim setup (only if not root)
# ----------------------------------------------------------------------
if [[ "$TARGET_USER" == "root" ]]; then
  echo "⚠️  Skipping LazyVim setup — running as root. LazyVim should be user-level only."
else
  NVIM_CONFIG_DIR="$TARGET_USER_HOME/.config/nvim"

  # Backup any existing config
  if [[ -d "$NVIM_CONFIG_DIR" ]]; then
    mv "$NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR.bak-$(date +%Y%m%d-%H%M%S)"
    echo "📦 Existing Neovim config backed up."
  fi

  echo "📥 Cloning LazyVim starter for user..."
  if sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/LazyVim/starter "$NVIM_CONFIG_DIR"; then
    sudo -u "$TARGET_USER" rm -rf "$NVIM_CONFIG_DIR/.git"
    echo "✅ LazyVim installed for $TARGET_USER"
  else
    echo "❌ Failed to clone LazyVim starter (check network)."
  fi
fi

# ----------------------------------------------------------------------
# 2. Oh My Tmux (manual non-interactive installation)
# ----------------------------------------------------------------------
echo "📦 Installing Oh My Tmux (non-interactive)..."

TMUX_DIR="$TARGET_USER_HOME/.tmux"
REPO_URL="https://github.com/gpakosz/.tmux.git"

# Clone or update the repo silently
if [[ -d "$TMUX_DIR/.git" ]]; then
  echo "🔄 Updating existing Oh My Tmux repo..."
  if ! git -C "$TMUX_DIR" pull --quiet; then
    echo "⚠️  Git pull failed, re-cloning..."
    rm -rf "$TMUX_DIR"
    git clone --depth=1 "$REPO_URL" "$TMUX_DIR"
  fi
else
  echo "📥 Cloning Oh My Tmux repo..."
  git clone --depth=1 "$REPO_URL" "$TMUX_DIR"
fi

# Manual installation (no curl, no prompt)
echo "🔗 Linking Tmux configuration files..."
ln -sfn "$TMUX_DIR/.tmux.conf" "$TARGET_USER_HOME/.tmux.conf"
cp -f "$TMUX_DIR/.tmux.conf.local" "$TARGET_USER_HOME/.tmux.conf.local"

# Fix ownership if running under sudo
if [[ "$(whoami)" == "root" ]]; then
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_USER_HOME/.tmux" "$TARGET_USER_HOME/.tmux.conf" "$TARGET_USER_HOME/.tmux.conf.local"
fi

echo "✅ Oh My Tmux installed and linked manually."
echo "✅ Developer tools configuration completed successfully."
