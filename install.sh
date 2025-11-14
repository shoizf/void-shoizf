#!/usr/bin/env bash
# install.sh — Main installer for void-shoizf (VM-aware)
# Run as a normal user (not root). Calls root-required installers with sudo.

set -euo pipefail

# --- Safety check ---
if [ "$EUID" -eq 0 ]; then
  echo "❌ This script should NOT be run as root."
  exit 1
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
INSTALLERS_DIR="$SCRIPT_DIR/installers"
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

log "▶ Starting install.sh"

# --- Source VM detection utility (repo-friendly detection) ---
if [ -f "$UTILS_DIR/is_vm.sh" ]; then
  # is_vm.sh prints true/false and sets IS_VM variable
  source "$UTILS_DIR/is_vm.sh"
  : "${IS_VM:=false}"
  log "INFO VM detection: IS_VM=${IS_VM}"
else
  IS_VM=false
  log "WARN utils/is_vm.sh not found; assuming IS_VM=false"
fi

# --- Determine TARGET_USER and HOME if not provided ---
TARGET_USER=${TARGET_USER:-$(whoami)}
TARGET_USER_HOME=${TARGET_USER_HOME:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}
if [ -z "$TARGET_USER_HOME" ]; then
  log "ERROR Could not determine TARGET_USER_HOME for $TARGET_USER"
  exit 1
fi
log "INFO Running installation for user: $TARGET_USER ($TARGET_USER_HOME)"

# --- Ordered installer list (adjust order as required) ---
INSTALLERS=(
  "install-packages" # requires sudo
  "add-font"
  "audio-integration"
  "awww"
  "dev-tools"
  "niri"
  "waybar"
  "hyprlock"
  "sddm_astronaut"
  "intel"
  "vulkan-intel"
  "nvidia"
  "networkman"
  "grub"
)

# --- Run installers ---
for installer in "${INSTALLERS[@]}"; do
  SCRIPT_PATH="$INSTALLERS_DIR/${installer}.sh"

  if [ ! -f "$SCRIPT_PATH" ]; then
    log "WARN Missing installer: $SCRIPT_PATH — skipping."
    continue
  fi

  # Skip certain hardware installers on VMs
  if [[ "$IS_VM" == true && "$installer" =~ ^(intel|nvidia|networkman)$ ]]; then
    log "SKIP ${installer}.sh — skipped for VM environment."
    continue
  fi

  log "▶ Running ${installer}.sh"

  # Decide whether to run with sudo (install-packages requires root)
  if [[ "$installer" == "install-packages" ]]; then
    # must be run as root — we call with sudo
    if sudo bash "$SCRIPT_PATH"; then
      log "OK ${installer}.sh completed (sudo)"
    else
      log "ERROR ${installer}.sh (sudo) failed — continuing"
    fi
  else
    # run as user; pass TARGET_USER and TARGET_USER_HOME for scripts that accept them
    if bash "$SCRIPT_PATH" "$TARGET_USER" "$TARGET_USER_HOME"; then
      log "OK ${installer}.sh completed"
    else
      log "ERROR ${installer}.sh failed — continuing"
    fi
  fi

done

log "✅ install.sh finished"
