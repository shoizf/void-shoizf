#!/bin/sh

# Font installation script for void-shoizf setup
# Installs required fonts via xbps and manually downloads/installs others.

# Determine Target User and Home Directory
TARGET_USER=${SUDO_USER:-$(logname || whoami)}
TARGET_USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_USER_HOME" ]; then
  echo "❌ [add-font.sh] Could not determine target user or home directory."
  exit 1
fi

# Define font directory for manual installs
FONT_DIR="$TARGET_USER_HOME/.local/share/fonts"
SHARE_DIR="$TARGET_USER_HOME/.local/share" # Base directory for downloads

# --- Install Fonts via xbps ---
echo "Installing font packages via xbps (sudo required)..."
FONT_PACKAGES="
    noto-fonts-emoji
    font-firacode
    font-awesome
    font-awesome5
    font-awesome6
    nerd-fonts-symbols-ttf
    terminus-font
    dejau-fonts-ttf
"
sudo xbps-install -Sy $FONT_PACKAGES
if [ $? -ne 0 ]; then
  echo "❌ [add-font.sh] Failed to install font packages via xbps."
  # Decide if this is fatal
  # exit 1
fi

# --- Manual Installation Section ---

echo "Ensuring font directory exists: $FONT_DIR"
mkdir -p "$FONT_DIR"

# Ensure curl and unzip are installed (needed for download/extraction)
if ! command -v curl >/dev/null || ! command -v unzip >/dev/null; then
  echo "Installing curl and unzip (sudo required)..."
  sudo xbps-install -Sy curl unzip
  if [ $? -ne 0 ]; then
    echo "❌ [add-font.sh] Failed to install curl/unzip."
    exit 1
  fi
fi

# --- Install JetBrains Mono Nerd Font ---
echo "Downloading JetBrains Mono Nerd Font..."
JB_ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
JB_ZIP_DEST="$SHARE_DIR/JetBrainsMono.zip"

# Download using curl
if curl -fLo "$JB_ZIP_DEST" "$JB_ZIP_URL"; then
  echo "Extracting JetBrains Mono Nerd Font to $FONT_DIR..."
  unzip -o "$JB_ZIP_DEST" -d "$FONT_DIR" # Use -o to overwrite existing without asking
  if [ $? -ne 0 ]; then
    echo "❌ [add-font.sh] Failed to extract JetBrains Mono Nerd Font."
    rm -f "$JB_ZIP_DEST" # Clean up zip even on failure
    exit 1               # Font is likely critical for Waybar config
  fi
  echo "Cleaning up JetBrains Mono download..."
  rm -f "$JB_ZIP_DEST"
else
  echo "❌ [add-font.sh] Failed to download JetBrains Mono Nerd Font from $JB_ZIP_URL."
  exit 1 # Font is likely critical
fi

# --- Install Symbols Nerd Font (as fallback) ---
# Note: This is now also installed via xbps, but downloading manually ensures
# we have it even if the package name changes or isn't available.
# We can keep this as a robust fallback.
echo "Downloading Symbols Nerd Font Only (fallback)..."
SYMBOLS_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SymbolsNerdFont-Only.ttf"
SYMBOLS_FONT_DEST="$FONT_DIR/Symbols Nerd Font Only.ttf"

# Download directly to font directory
if curl -fLo "$SYMBOLS_FONT_DEST" "$SYMBOLS_FONT_URL"; then
  echo "Symbols Nerd Font (fallback) downloaded."
else
  echo "❌ [add-font.sh] Failed to download Symbols Nerd Font Only from $SYMBOLS_FONT_URL."
  echo "⚠️ Warning: Symbols font download failed, some icons might be missing if xbps package fails."
fi

# --- Refresh Font Cache ---
echo "Refreshing font cache..."
# Run fc-cache as the target user, not root
sudo -u "$TARGET_USER" fc-cache -f -v

echo "✅ Font installation script finished."
