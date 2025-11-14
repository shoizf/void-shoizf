#!/usr/bin/env bash
# installers/audio-integration.sh — install PipeWire & audio utilities

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

log "▶ audio-integration.sh starting"

if [ "$EUID" -eq 0 ]; then
  log "ERROR Do not run audio-integration.sh as root. Exiting."
  exit 1
fi

PKGS=(pipewire wireplumber pipewire-pulse alsa-utils pavucontrol libspa-alsa sof-firmware)
log "INFO Installing audio packages: ${PKGS[*]}"
sudo xbps-install -Sy --yes "${PKGS[@]}" || log "WARN Some audio packages failed to install"

# Link ALSA config for PipeWire (if present)
if [ -f /usr/share/alsa/alsa.conf.d/50-pipewire.conf ]; then
  sudo mkdir -p /etc/alsa/conf.d || true
  sudo ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/50-pipewire.conf || true
  log "OK ALSA configured to use PipeWire (symlink created)"
fi

log "✅ audio-integration.sh finished"
