#!/usr/bin/env bash
# install.sh — Master Orchestrator (User-Driven Mode)
# Version: 1.1.0
# Updated: 2025-12-10
#
# Runs as USER. Handles environment, logging, VM detection, execution order
# and delegates logs to ROOT and USER installers through VOID_SHOIZF_MASTER_LOG.
#
# All installers live inside ./installers and follow template rules.

set -euo pipefail

# ------------------------------------------------------
# 1. USER VALIDATION (User-Driven)
# ------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
  cat <<EOF >&2
❌ ERROR: This script must NOT be run as root.
👉 Usage: ./install.sh   (run as your normal user)
EOF
  exit 1
fi

echo "🔒 Requesting sudo privileges for Root-Level installers..."
if ! sudo -v; then
  echo "❌ Sudo authentication failed." >&2
  exit 1
fi

# Keep sudo alive during execution
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# ------------------------------------------------------
# 2. TARGET USER + LOGGING SETUP
# ------------------------------------------------------
TARGET_USER="$USER"
TARGET_HOME="$HOME"
TARGET_GROUP="$(id -gn)"

echo "🚀 Initializing install for: $TARGET_USER ($TARGET_HOME)"

LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
MASTER_NAME="void-shoizf-master"
MASTER_LOG_FILE="$LOG_DIR/${MASTER_NAME}-${TIMESTAMP}.log"

: >"$MASTER_LOG_FILE"

export VOID_SHOIZF_MASTER_LOG="$MASTER_LOG_FILE"
export TARGET_USER
export TARGET_HOME

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [MASTER] $*"
  echo "$msg" | tee -a "$MASTER_LOG_FILE"
}

log "▶ Starting Master Installation"

# ------------------------------------------------------
# 3. PATHS & VM CHECK
# ------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
INSTALLERS_DIR="$SCRIPT_DIR/installers"

IS_VM=false
if [ -f "$UTILS_DIR/is_vm.sh" ]; then
  # shellcheck disable=SC1090
  source "$UTILS_DIR/is_vm.sh" || true
  : "${IS_VM:=false}"
  log "INFO VM detection: IS_VM=$IS_VM"
fi

# ------------------------------------------------------
# 4. CORE SERVICES (DBUS & RTKIT)
# ------------------------------------------------------
log "Configuring core services..."

SV_DIR="/etc/sv"
RUNIT_DIR="/etc/runit/runsvdir/default"

# Enable dbus
if [ -d "$SV_DIR/dbus" ]; then
  if [ ! -L "$RUNIT_DIR/dbus" ]; then
    sudo ln -s "$SV_DIR/dbus" "$RUNIT_DIR/dbus"
    log "OK Enabled: dbus"
  else
    log "INFO dbus already active"
  fi
else
  log "WARN dbus service not present yet (likely installed later)"
fi

# Enable rtkit (PipeWire realtime)
if [ -d "$SV_DIR/rtkit" ]; then
  if [ ! -L "$RUNIT_DIR/rtkit" ]; then
    sudo ln -sf "$SV_DIR/rtkit" "$RUNIT_DIR/rtkit"
    log "OK Enabled: rtkit"
  fi
else
  log "WARN rtkit service missing"
fi

log "✅ Core services configured."

# ------------------------------------------------------
# 5. SCRIPT GROUP DEFINITIONS
# ------------------------------------------------------
ROOT_SCRIPTS=(
  "repos"
  "hyprlock"
  "sddm_astronaut"
  "intel"
  "vulkan"
  "nvidia"
  "networkman"
  "grub"
)

USER_SCRIPTS=(
  "packages"
  "fonts"
  "audio"
  "awww"
  "dev-tools"
  "niri"
  "waybar"
  "mako"
  "sddm_theme_selector"
)

EXECUTION_ORDER=(
  "repos"
  "packages"
  "fonts"
  "audio"
  "awww"
  "dev-tools"
  "niri"
  "waybar"
  "hyprlock"
  "mako"
  "sddm_theme_selector"
  "sddm_astronaut"
  "intel"
  "nvidia"
  "vulkan"
  "grub"
  "networkman"
)

# ------------------------------------------------------
# 6. EXECUTION LOOP
# ------------------------------------------------------
for script_name in "${EXECUTION_ORDER[@]}"; do
  SCRIPT_PATH="$INSTALLERS_DIR/${script_name}.sh"

  if [ ! -f "$SCRIPT_PATH" ]; then
    log "WARN Missing installer: $SCRIPT_PATH — skipping"
    continue
  fi

  # VM Skip Logic
  if [[ "$IS_VM" == true && "$script_name" =~ ^(intel|nvidia|vulkan)$ ]]; then
    log "SKIP ${script_name}.sh — skipped inside VM"
    continue
  fi

  # Determine mode (root/user)
  MODE="USER"
  for r in "${ROOT_SCRIPTS[@]}"; do
    if [[ "$script_name" == "$r" ]]; then
      MODE="ROOT"
      break
    fi
  done

  log "▶ Running ${script_name}.sh [Mode: $MODE]"

  if [[ "$MODE" == "ROOT" ]]; then
    if sudo -E env \
      "VOID_SHOIZF_MASTER_LOG=$VOID_SHOIZF_MASTER_LOG" \
      "TARGET_USER=$TARGET_USER" \
      "TARGET_HOME=$TARGET_HOME" \
      bash "$SCRIPT_PATH" 2>&1 | tee -a "$MASTER_LOG_FILE"; then
      log "OK ${script_name}.sh completed"
    else
      log "ERROR ${script_name}.sh FAILED (root mode)"
    fi

  else
    if sudo -u "$TARGET_USER" -H env \
      "HOME=$TARGET_HOME" \
      "TARGET_USER=$TARGET_USER" \
      "TARGET_HOME=$TARGET_HOME" \
      "VOID_SHOIZF_MASTER_LOG=$VOID_SHOIZF_MASTER_LOG" \
      bash "$SCRIPT_PATH" 2>&1 | tee -a "$MASTER_LOG_FILE"; then
      log "OK ${script_name}.sh completed"
    else
      log "ERROR ${script_name}.sh FAILED (user mode)"
    fi
  fi
done

log "🎉 Installation Sequence Complete."
exit 0
