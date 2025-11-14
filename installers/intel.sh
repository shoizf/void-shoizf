#!/usr/bin/env bash
# installers/intel.sh — install Intel GPU drivers & helpers

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
