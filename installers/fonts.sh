#!/usr/bin/env bash
# installers/fonts.sh — Install fonts (Read from Repo / Download to Cache)

set -euo pipefail

# --- Logging setup ---
LOG_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/void-shoizf/log"
mkdir -p "$LOG_BASE"
SCRIPT_NAME="$(basename "$0" .sh)"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_BASE/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}
# --- End Logging setup ---

log "▶ fonts.sh starting"

# --- PATHS SETUP ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
# External Cache for downloads (Keeps repo clean!)
DOWNLOAD_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/void-shoizf/fonts"

# Detect Repo for READING local assets only
if [[ "$SCRIPT_DIR" == */installers ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  REPO_ASSETS="$REPO_ROOT/assets/fonts"
  log "INFO Repo detected. Reading custom fonts from: $REPO_ASSETS"
else
  # Fallback if script is moved
  REPO_ASSETS="${XDG_DATA_HOME:-$HOME/.local/share}/void-shoizf/assets/fonts"
  log "INFO Standalone run. Reading custom fonts from: $REPO_ASSETS"
fi

mkdir -p "$DEST_DIR"
mkdir -p "$DOWNLOAD_CACHE"

# --- PART 1: INSTALL LOCAL REPO FONTS (READ ONLY) ---
if [ -d "$REPO_ASSETS" ]; then
  log "▶ Installing bundled fonts from repo..."
  # Find only otf/ttf/OTF/TTF files
  find "$REPO_ASSETS" -type f \( -iname "*.ttf" -o -iname "*.otf" \) | while read -r f; do
    fname="$(basename "$f")"
    if [ ! -f "$DEST_DIR/$fname" ]; then
      cp -f "$f" "$DEST_DIR/$fname"
      chmod 644 "$DEST_DIR/$fname"
      log "➕ Installed bundled font: $fname"
    fi
  done
else
  log "WARN Repo assets folder not found ($REPO_ASSETS). Skipping bundled fonts."
fi

# --- PART 2: DOWNLOAD & INSTALL EXTERNAL FONTS (WRITE TO CACHE) ---
JB_DIR="$DOWNLOAD_CACHE/JetBrainsMono"

# We check the CACHE, not the REPO
if [ ! -d "$JB_DIR" ]; then
  log "⬇️ JetBrains Mono (Nerd Font) missing in cache. Downloading..."

  if ! command -v wget &>/dev/null; then sudo xbps-install -S wget unzip; fi

  mkdir -p "$JB_DIR"
  URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"

  if wget -q --show-progress -O "$JB_DIR/archive.zip" "$URL"; then
    unzip -o -q "$JB_DIR/archive.zip" -d "$JB_DIR"
    rm "$JB_DIR/archive.zip"
    rm -rf "$JB_DIR/__MACOSX"
    log "OK JetBrains Mono downloaded to cache."
  else
    log "ERROR Failed to download JetBrains Mono."
    rm -rf "$JB_DIR"
  fi
else
  log "INFO JetBrains Mono found in cache. Installing..."
fi

# Install from Cache
if [ -d "$JB_DIR" ]; then
  find "$JB_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" \) | while read -r f; do
    fname="$(basename "$f")"
    if [ ! -f "$DEST_DIR/$fname" ]; then
      cp -f "$f" "$DEST_DIR/$fname"
      chmod 644 "$DEST_DIR/$fname"
      # log "➕ Installed cached font: $fname" # Commented to reduce log spam for 80+ files
    fi
  done
fi

log "🔄 Refreshing font cache..."
if fc-cache -fv "$DEST_DIR" >/dev/null 2>&1; then
  log "✅ Font cache updated."
else
  log "WARN fc-cache failed."
fi

log "✅ fonts.sh finished"
