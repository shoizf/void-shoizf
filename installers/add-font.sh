#!/usr/bin/env bash
# installers/add-font.sh

# Determine script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Determine Target User and Home Directory
TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_USER_HOME" ]; then
  echo "❌ [add-font.sh] Could not determine target user or home directory."
  exit 1
fi

FONT_DIR="$TARGET_USER_HOME/.local/share/fonts"
SHARE_DIR="$TARGET_USER_HOME/.local/share"

echo "Installing font packages via xbps (sudo required)..."
FONT_PACKAGES="
    noto-fonts-emoji
    font-firacode
    font-awesome
    font-awesome5
    font-awesome6
    nerd-fonts-symbols-ttf
    terminus-font
    dejavu-fonts-ttf
    liberation-fonts-ttf
    noto-fonts-cjk
"
sudo xbps-install -Sy $FONT_PACKAGES || echo "⚠️ Some font packages may not have installed properly."

echo "Ensuring font directory exists: $FONT_DIR"
mkdir -p "$FONT_DIR"

if ! command -v curl >/dev/null || ! command -v unzip >/dev/null; then
  echo "Installing curl and unzip (sudo required)..."
  sudo xbps-install -Sy curl unzip
fi

echo "Downloading JetBrains Mono Nerd Font..."
JB_ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
JB_ZIP_DEST="$SHARE_DIR/JetBrainsMono.zip"

if curl -fLo "$JB_ZIP_DEST" "$JB_ZIP_URL"; then
  echo "Extracting JetBrains Mono Nerd Font to $FONT_DIR..."
  unzip -o "$JB_ZIP_DEST" -d "$FONT_DIR"
  rm -f "$JB_ZIP_DEST"
else
  echo "❌ [add-font.sh] Failed to download JetBrains Mono Nerd Font."
  exit 1
fi

echo "Downloading Symbols Nerd Font Only (fallback)..."
SYMBOLS_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SymbolsNerdFont-Only.ttf"
SYMBOLS_FONT_DEST="$FONT_DIR/Symbols Nerd Font Only.ttf"

if ! curl -fLo "$SYMBOLS_FONT_DEST" "$SYMBOLS_FONT_URL"; then
  echo "⚠️ [add-font.sh] Warning: Symbols font download failed."
fi

echo "Refreshing font cache..."
sudo -u "$TARGET_USER" fc-cache -f -v

echo "✅ Font installation script finished."
