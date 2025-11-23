#!/usr/bin/env bash
# installers/audio.sh — configure PipeWire & ALSA
# Run as USER.

set -euo pipefail

# --- Logging setup ---
LOG_DIR="$HOME/.local/state/void-shoizf/log"
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

log "▶ audio.sh starting"

# --- CONFIGURATION ONLY ---

# Link ALSA config for PipeWire (Requires sudo for /etc write)
ALSA_SRC="/usr/share/alsa/alsa.conf.d/50-pipewire.conf"
ALSA_DEST="/etc/alsa/conf.d/50-pipewire.conf"

if [ -f "$ALSA_SRC" ]; then
  log "INFO Linking ALSA to Pipewire..."
  # Using sudo mkdir/ln because /etc/alsa is root-owned
  sudo mkdir -p /etc/alsa/conf.d
  sudo ln -sf "$ALSA_SRC" "$ALSA_DEST"
  log "OK ALSA configured"
else
  log "WARN ALSA/Pipewire config file missing at $ALSA_SRC"
fi

log "✅ audio.sh finished"
