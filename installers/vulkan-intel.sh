#!/usr/bin/env bash
# installers/vulkan-intel.sh — install Intel Vulkan ICDs & helpers

set -euo pipefail

LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
MASTER_LOG="$LOG_DIR/master-install.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" | tee -a "$LOG_FILE" >>"$MASTER_LOG"; }

log "▶ vulkan-intel.sh starting"

if [ "$EUID" -ne 0 ]; then
  log "ERROR vulkan-intel.sh must be run as root"
  exit 1
fi

xbps-install -Sy --yes mesa-vulkan-intel mesa-vulkan-intel-32bit vulkan-loader vulkan-loader-32bit vulkan-headers vulkan-validationlayers mesa-vulkan-lavapipe || log "WARN Vulkan packages may have issues"

if ! grep -q 'VK_ICD_FILENAMES' "$HOME/.bash_profile" 2>/dev/null; then
  echo 'export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json' >>"$HOME/.bash_profile"
  log "OK Added VK_ICD_FILENAMES to $HOME/.bash_profile"
fi

log "✅ vulkan-intel.sh finished"
