#!/usr/bin/env bash
# installers/intel.sh — install Intel GPU drivers & helpers

set -euo pipefail

# --- Logging setup ---
# Find the user's home dir for logging, even when run as root
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_HOME="$HOME"
fi

LOG_DIR="$USER_HOME/.local/log/void-shoizf"
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

log "▶ intel.sh starting"

if [ "$EUID" -eq 0 ]; then
  log "INFO installing Intel packages (running as root)"
else
  log "ERROR intel.sh must be run with sudo/root"
  exit 1
fi

PACKAGES=(mesa-dri mesa-dri-32bit mesa-demos xf86-video-intel)
xbps-install -Sy --yes "${PACKAGES[@]}" || log "WARN Some intel packages failed"

log "✅ intel.sh finished"
