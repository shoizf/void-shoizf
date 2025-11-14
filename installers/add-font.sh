#!/usr/bin/env bash
# installers/add-font.sh — install repo fonts into user's local fonts

set -euo pipefail

# --- Logging setup ---
LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
SCRIPT_NAME="$(basename "$0" .sh)"

# Check if we're being run by the master installer
if [ -n "$VOID_SHOIZF_MASTER_LOG" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  # We are being run directly, create our own log
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}
# --- End Logging setup ---

log "▶ add-font.sh starting"

if [ "$EUID" -eq 0 ]; then
  log "ERROR Do not run add-font.sh as root. Exiting."
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="$REPO_ROOT/assets/fonts"
DEST_DIR="$HOME/.local/share/fonts/custom"
mkdir -p "$DEST_DIR"

shopt -s nullglob
count=0
for f in "$ASSET_DIR"/*/*; do
  fname="$(basename "$f")"
  cp -f "$f" "$DEST_DIR/$fname"
  chmod 644 "$DEST_DIR/$fname"
  log "OK Installed font: $fname"
  count=$((count + 1))
done
shopt -u nullglob

if ((count == 0)); then
  log "WARN No fonts found under $ASSET_DIR"
else
  log "OK Installed $count fonts to $DEST_DIR"
fi

fc-cache -fv "$HOME/.local/share/fonts" >/dev/null 2>&1 || log "WARN fc-cache refresh failed"
log "✅ add-font.sh finished"
