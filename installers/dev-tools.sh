#!/usr/bin/env bash
# installers/dev-tools.sh — install LazyVim, tmux config, Obsidian

set -euo pipefail

LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
MASTER_LOG="$LOG_DIR/master-install.log"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE" >>"$MASTER_LOG"
}

log "▶ dev-tools.sh starting"

if [ "$EUID" -eq 0 ]; then
  log "ERROR Do not run dev-tools.sh as root. Exiting."
  exit 1
fi

# LazyVim
log "INFO Installing LazyVim starter"
rm -rf "$HOME/.config/nvim" "$HOME/.local/share/nvim" || true
if git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"; then
  log "OK LazyVim cloned"
else
  log "WARN LazyVim clone failed"
fi

# tmux config
log "INFO Installing Oh My Tmux!"
rm -rf "$HOME/.tmux" "$HOME/.tmux.conf" || true
if git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux"; then
  ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
  cp "$HOME/.tmux/.tmux.conf.local" "$HOME/" || true
  log "OK tmux config installed"
else
  log "WARN tmux clone failed"
fi

# Obsidian AppImage (best-effort)
log "INFO Installing Obsidian AppImage (best-effort)"
# use the existing logic but don't fail the script on network errors

fetch_latest_appimage_url() {
  # minimal fallback extractor
  curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest 2>/dev/null |
    grep -oE 'https://[^"]+\.AppImage' | head -n1 || true
}

LATEST_URL="$(fetch_latest_appimage_url)"
if [ -n "$LATEST_URL" ]; then
  TMPFILE="$(mktemp /tmp/obsidian.XXXXXX)"
  if curl -fL -s -o "$TMPFILE" "$LATEST_URL"; then
    mkdir -p "$HOME/.local/bin"
    mv "$TMPFILE" "$HOME/.local/bin/obsidian.AppImage"
    chmod +x "$HOME/.local/bin/obsidian.AppImage"
    ln -sf "$HOME/.local/bin/obsidian.AppImage" "$HOME/.local/bin/obsidian"
    log "OK Obsidian AppImage installed"
  else
    log "WARN Failed to download Obsidian AppImage"
  fi
else
  log "WARN Could not determine Obsidian download URL"
fi

log "✅ dev-tools.sh finished"
