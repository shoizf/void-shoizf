#!/usr/bin/env bash
# =============================================================================
# add-font.sh — Installs Hyprlock + Developer fonts locally for the current user
# Works on: Void Linux
#
# 📦 Installs system base fonts (via xbps)
# 🪶 Copies Hyprlock custom OTF fonts from assets/fonts/** → ~/.local/share/fonts/custom/
# 🪵 Logs actions to ~/.local/log/void-shoizf/add-font.log
#
# 🧠 Credits:
#   - Original Hyprlock configuration & fonts concept from Kaushal (Envii)
#     Source: https://github.com/Makrennel/hyprlock
# =============================================================================

set -euo pipefail

# --- Path setup ---
REPO_DIR="$(dirname "$(realpath "$0")")/.."
ASSET_DIR="$REPO_DIR/assets/fonts"
LOG_DIR="$HOME/.local/log/void-shoizf"
FONT_DIR="$HOME/.local/share/fonts"
CUSTOM_DIR="$FONT_DIR/custom"

mkdir -p "$LOG_DIR" "$CUSTOM_DIR"

LOG_FILE="$LOG_DIR/add-font.log"

# --- Logging setup ---
exec > >(tee -a "$LOG_FILE") 2>&1
timestamp() { date +"[%Y-%m-%d %H:%M:%S]"; }

echo "$(timestamp) 🧾 Logging to: $LOG_FILE"
echo "$(timestamp) 🔧 Installing developer + Hyprlock fonts for user: $USER"
echo "$(timestamp) ------------------------------------------------------------"

# --- Step 1: Install system fonts via XBPS ---
echo "$(timestamp) 📦 Installing base font packages..."
sudo xbps-install -Sy \
  font-awesome font-awesome5 font-awesome6 nerd-fonts-symbols-ttf \
  terminus-font dejavu-fonts-ttf liberation-fonts-ttf \
  noto-fonts-cjk noto-fonts-emoji font-firacode ||
  echo "$(timestamp) ⚠️ Some base fonts might already be installed or failed to update."

# --- Step 2: Copy bundled OTF fonts from assets ---
echo "$(timestamp) 📁 Installing Hyprlock custom fonts from assets directory..."

declare -A FONT_PATHS=(
  ["Metropolis-Medium.otf"]="$ASSET_DIR/metropolis/Metropolis-Medium.otf"
  ["SFPRODISPLAYMEDIUM.OTF"]="$ASSET_DIR/sf-pro-display/SFPRODISPLAYMEDIUM.OTF"
  ["Stange Bold OTF.otf"]="$ASSET_DIR/stange/Stange Bold OTF.otf"
)

for font in "${!FONT_PATHS[@]}"; do
  SRC="${FONT_PATHS[$font]}"
  DEST="$CUSTOM_DIR/$font"

  if [[ -f "$DEST" ]]; then
    echo "$(timestamp) ♻️ Removing old version of $font..."
    rm -f "$DEST"
  fi

  if [[ -f "$SRC" ]]; then
    echo "$(timestamp) 📦 Installing new version of $font..."
    cp "$SRC" "$DEST"
    chmod 644 "$DEST"
    echo "$(timestamp) ✅ $font successfully updated."
  else
    echo "$(timestamp) ⚠️ Missing font in repo: $SRC"
  fi
done

# --- Step 3: Refresh font cache ---
echo "$(timestamp) 🔄 Refreshing font cache..."
if [[ -d "$HOME/.fontconfig" ]]; then
  # If legacy directory exists, show full fc-cache output (for transparency)
  fc-cache -fv "$FONT_DIR"
else
  # Otherwise, hide only the benign “not cleaning non-existent cache directory” notice
  fc-cache -fv "$FONT_DIR" 2>&1 | grep -v "not cleaning non-existent cache directory"
fi

# --- Step 4: Verification summary ---
echo "$(timestamp) 🧩 Installed custom fonts:"
find "$CUSTOM_DIR" -type f -iname "*.otf" | sed 's/^/   /'

echo "$(timestamp) ------------------------------------------------------------"
echo "$(timestamp) 🎉 Font installation completed successfully for $USER."
echo "$(timestamp) 🪶 Log saved to: $LOG_FILE"
