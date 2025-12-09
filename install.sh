#!/usr/bin/env bash
# install.sh — Master Orchestrator (User-Driven Mode)
# USER-SCRIPT (run as normal user; uses sudo internally)

# ------------------------------------------------------
#  void-shoizf Script Version
# ------------------------------------------------------
#  Name: install.sh
#  Version: 1.1.0
#  Updated: 2025-12-09
#  Purpose: Drive the full Void + Niri setup, handing off
#           logging to child installers and keeping a
#           single master log per run.
# ------------------------------------------------------

set -euo pipefail

# ------------------------------------------------------
# 1. USER VALIDATION (MUST be non-root)
# ------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
  cat <<EOF >&2
❌ ERROR: This script must NOT be run as ROOT.

👉 Usage:
   ./install.sh    # run as your normal user
EOF
  exit 1
fi

# ------------------------------------------------------
# 2. PREPARE SUDO (cache credentials & keep alive)
# ------------------------------------------------------
echo "🔒 Requesting sudo privileges for root-level installers..."
if ! sudo -v; then
  echo "❌ Sudo authentication failed." >&2
  exit 1
fi

# Keep sudo timestamp alive in the background
# (best-effort; errors ignored to avoid noisy output)
while true; do
  sudo -n true 2>/dev/null || true
  sleep 60
  kill -0 "$$" 2>/dev/null || exit
done &

# ------------------------------------------------------
# 3. TARGET USER CONTEXT
# ------------------------------------------------------
TARGET_USER="$USER"
TARGET_HOME="$HOME"
TARGET_GROUP="$(id -gn)"

echo "🚀 Initializing User-Driven Installation for: $TARGET_USER ($TARGET_HOME)"

# ------------------------------------------------------
# 4. MASTER LOGGING SETUP
# ------------------------------------------------------
LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="void-shoizf-master"
MASTER_LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"

# Create the master log as the user
: >"$MASTER_LOG_FILE"

export VOID_SHOIZF_MASTER_LOG="$MASTER_LOG_FILE"
export TARGET_USER
export TARGET_HOME

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [MASTER] $*"
  echo "$msg" | tee -a "$MASTER_LOG_FILE"
}

log "▶ Starting User-Driven Install for $TARGET_USER"

# ------------------------------------------------------
# 5. PATHS & VM DETECTION
# ------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
INSTALLERS_DIR="$SCRIPT_DIR/installers"

IS_VM=false
if [ -f "$UTILS_DIR/is_vm.sh" ]; then
  # shellcheck disable=SC1090
  if source "$UTILS_DIR/is_vm.sh"; then
    : "${IS_VM:=false}"
  else
    IS_VM=false
  fi
  log "INFO VM detection: IS_VM=${IS_VM}"
else
  log "WARN utils/is_vm.sh missing — assuming bare metal"
fi

# ------------------------------------------------------
# 6. CORE SYSTEM SERVICES (Tier 0)
# ------------------------------------------------------
log "Configuring core services (dbus/rtkit)..."

SV_DIR="/etc/sv"
RUNIT_DIR="/etc/runit/runsvdir/default"

# dbus activation
if [ -d "$SV_DIR/dbus" ]; then
  if [ ! -L "$RUNIT_DIR/dbus" ]; then
    sudo ln -s "$SV_DIR/dbus" "$RUNIT_DIR/dbus"
    log "OK Enabled core service: dbus"
  else
    log "INFO Core service dbus already active"
  fi
else
  log "WARN dbus service directory not found under $SV_DIR"
fi

# rtkit for PipeWire realtime audio
if [ -d "$SV_DIR/rtkit" ]; then
  if [ ! -L "$RUNIT_DIR/rtkit" ]; then
    sudo ln -s "$SV_DIR/rtkit" "$RUNIT_DIR/rtkit"
    log "OK Enabled core service: rtkit"
  else
    log "INFO Core service rtkit already active"
  fi
else
  log "WARN rtkit service directory not found under $SV_DIR"
fi

log "✅ Core services configured."

# ------------------------------------------------------
# 7. INSTALLER DEFINITIONS
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

# helper: check if script is ROOT-mode
is_root_script() {
  local name="$1"
  for r in "${ROOT_SCRIPTS[@]}"; do
    if [ "$r" = "$name" ]; then
      return 0
    fi
  done
  return 1
}

# ------------------------------------------------------
# 8. EXECUTION ENGINE
# ------------------------------------------------------
for script_name in "${EXECUTION_ORDER[@]}"; do
  SCRIPT_PATH="$INSTALLERS_DIR/${script_name}.sh"

  if [ ! -f "$SCRIPT_PATH" ]; then
    log "WARN Missing installer: $SCRIPT_PATH — skipping."
    continue
  fi

  # VM skip logic (GPU / networkman checks)
  if [[ "$IS_VM" == true && "$script_name" =~ ^(intel|vulkan|vulkan-intel|nvidia|networkman)$ ]]; then
    log "SKIP ${script_name}.sh — skipped for VM environment."
    continue
  fi

  MODE="USER"
  if is_root_script "$script_name"; then
    MODE="ROOT"
  fi

  log "▶ Running ${script_name}.sh [Mode: $MODE]"

  if [ "$MODE" = "ROOT" ]; then
    if sudo -E env \
      "TARGET_USER=$TARGET_USER" \
      "TARGET_HOME=$TARGET_HOME" \
      "VOID_SHOIZF_MASTER_LOG=$VOID_SHOIZF_MASTER_LOG" \
      bash "$SCRIPT_PATH" 2>&1 | tee -a "$MASTER_LOG_FILE"
    then
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
      bash "$SCRIPT_PATH" 2>&1 | tee -a "$MASTER_LOG_FILE"
    then
      log "OK ${script_name}.sh completed"
    else
      log "ERROR ${script_name}.sh FAILED (user mode)"
    fi
  fi
done

# ------------------------------------------------------
# 9. END
# ------------------------------------------------------
log "✅ Installation sequence complete."
echo
echo "Master log written to:"
echo "  $MASTER_LOG_FILE"
echo
exit 0
