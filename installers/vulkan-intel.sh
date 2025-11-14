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

# Find the user who ran 'sudo'
TARGET_USER=${SUDO_USER:-$(logname || whoami)}
TARGET_USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if [ -z "$TARGET_USER_HOME" ]; then
  log "ERROR Could not find user home to write .bash_profile. Exiting."
  exit 1
fi

xbps-install -Sy --yes mesa-vulkan-intel mesa-vulkan-intel-32bit vulkan-loader vulkan-loader-32bit vulkan-headers vulkan-validationlayers mesa-vulkan-lavapipe || log "WARN Vulkan packages may have issues"

# (Logic improved per review suggestion)
target_profile="$TARGET_USER_HOME/.bash_profile"

# Now, write to the correct user's home
if ! grep -q 'VK_ICD_FILENAMES' "$target_profile" 2>/dev/null; then
  log "INFO Adding VK_ICD_FILENAMES to $target_profile"
  echo 'export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json' >>"$target_profile"
  chown "$TARGET_USER:$TARGET_USER" "$target_profile"
  log "OK Added VK_ICD_FILENAMES to $target_profile"
else
  log "OK VK_ICD_FILENAMES already present in $target_profile"
fi

log "✅ vulkan-intel.sh finished"
