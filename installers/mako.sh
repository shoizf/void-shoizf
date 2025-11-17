#!/usr/bin/env bash
# installers/mako.sh — install mako + copy config
# Mako integration for void-shoizf.
# Includes behavior patterns inspired by Omarchy and
# colors adapted from Tokyo Night.

set -euo pipefail

# --- Logging setup ---
LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
SCRIPT_NAME="$(basename "$0" .sh)"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}
# --- End Logging setup ---

log "▶ mako installer starting"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
SOURCE_CFG="$REPO_ROOT/configs/mako/config"

# Detect VM if util exists
if [ -f "$REPO_ROOT/utils/is_vm.sh" ]; then
  source "$REPO_ROOT/utils/is_vm.sh" || true
else
  IS_VM=false
fi
log "INFO IS_VM=${IS_VM}"

# --- Install mako ---
log "INFO Installing mako"
sudo xbps-install -y mako || log "INFO mako already installed"

# --- Copy config (NO SYMLINKS) ---
DEST_DIR="$HOME/.config/mako"
mkdir -p "$DEST_DIR"

log "INFO Copying mako config → $DEST_DIR/config"
cp -f "$SOURCE_CFG" "$DEST_DIR/config"

log "INFO No runtime actions; mako will start when niri loads"
log "▶ Add to niri: spawn-at-startup \"mako\""

log "✅ mako installer finished"
