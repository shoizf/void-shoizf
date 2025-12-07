#!/usr/bin/env bash
# install.sh — Master Orchestrator (User-Driven Mode)
# Run this as your normal user (shoi). Preserves all original arrays, checks, and VM logic.

set -euo pipefail

# --- 1. USER VALIDATION (User-Driven) ---
if [ "$EUID" -eq 0 ]; then
  cat <<EOF >&2
❌ ERROR: This script must NOT be run as ROOT.
👉 Usage: ./install.sh (Run as your standard user)
EOF
  exit 1
fi

# Cache sudo credentials upfront (for ROOT_SCRIPTS)
echo "🔒 Requesting sudo privileges for Root-Level installers..."
if ! sudo -v; then
  echo "❌ Sudo authentication failed." >&2
  exit 1
fi

# Keep sudo alive in background
# (This loop intentionally runs in background to keep the timestamp alive)
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# --- 2. TARGET USER CONFIGURATION ---
TARGET_USER="$USER"
TARGET_HOME="$HOME"
TARGET_GROUP="$(id -gn)"

echo "🚀 Initializing User-Driven Installation for: $TARGET_USER ($TARGET_HOME)"

# --- 3. LOGGING SETUP ---
LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="void-shoizf-master"
MASTER_LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"

# Create file as USER (so ownership is user)
: >"$MASTER_LOG_FILE"

export VOID_SHOIZF_MASTER_LOG="$MASTER_LOG_FILE"
export TARGET_USER
export TARGET_HOME

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [MASTER] $*"
  # append as user
  echo "$msg" | tee -a "$MASTER_LOG_FILE"
}

log "▶ Starting User-Driven Install for $TARGET_USER"

# --- 4. PATHS & CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
INSTALLERS_DIR="$SCRIPT_DIR/installers"

# VM Detection (preserve existing behavior)
IS_VM=false
if [ -f "$UTILS_DIR/is_vm.sh" ]; then
  # is_vm.sh should set a variable or exit non-zero; guard with default
  # shellcheck disable=SC1090
  source "$UTILS_DIR/is_vm.sh" || true
  : "${IS_VM:=false}"
  log "INFO VM detection: IS_VM=${IS_VM}"
fi

# --- 5. CORE SYSTEM SERVICES (Tier 0) ---
log "Configuring Core Services..."

SV_DIR="/etc/sv"
RUNIT_DIR="/etc/runit/runsvdir/default"

# DBUS activation (must run with sudo to write /etc/runit)
if [ -d "$SV_DIR/dbus" ]; then
  if [ ! -L "$RUNIT_DIR/dbus" ]; then
    sudo ln -s "$SV_DIR/dbus" "$RUNIT_DIR/dbus"
    log "OK Enabled Core Service: dbus"
  else
    log "INFO Core Service dbus already active"
  fi
else
  log "WARN dbus service not found (packages.sh will likely install it next)"
fi

# RTKIT for PipeWire realtime audio
if [ -d "$SV_DIR/rtkit" ]; then
  if [ ! -L "$RUNIT_DIR/rtkit" ]; then
    log "INFO Enabling rtkit service..."
    sudo ln -sf "$SV_DIR/rtkit" "$RUNIT_DIR/rtkit"
  fi
else
  log "WARN rtkit service not found (Audio priority may suffer)"
fi

log "✅ Core Services Configured."

# --- 6. INSTALLER DEFINITIONS (preserve lists exactly) ---
ROOT_SCRIPTS=(
  "repos"
  "hyprlock"
  "sddm_astronaut"
  "intel"
  "vulkan-intel"
  "nvidia"
  "networkman"
  "grub"
  "audio"
)

USER_SCRIPTS=(
  "packages"
  "fonts"
  "awww"
  "dev-tools"
  "niri"
  "waybar"
  "mako"
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
  "sddm_astronaut"
  "intel"
  "vulkan-intel"
  "nvidia"
  "networkman"
  "grub"
)

# --- 7. EXECUTION ENGINE ---
for script_name in "${EXECUTION_ORDER[@]}"; do
  SCRIPT_PATH="$INSTALLERS_DIR/${script_name}.sh"

  if [ ! -f "$SCRIPT_PATH" ]; then
    log "WARN Missing installer: $SCRIPT_PATH — skipping."
    continue
  fi

  # VM Skip Logic (preserve)
  if [[ "$IS_VM" == true && "$script_name" =~ ^(intel|vulkan-intel|nvidia|networkman)$ ]]; then
    log "SKIP ${script_name}.sh — skipped for VM environment."
    continue
  fi

  # Determine Mode (preserve classification)
  MODE="USER"
  for r in "${ROOT_SCRIPTS[@]}"; do
    if [[ "$r" == "$script_name" ]]; then
      MODE="ROOT"
      break
    fi
  done

  log "▶ Executing ${script_name}.sh [Mode: $MODE]"

  if [[ "$MODE" == "ROOT" ]]; then
    # Run script as root, inject TARGET_USER/TARGET_HOME explicitly
    if sudo -E env \
      "TARGET_USER=$TARGET_USER" \
      "TARGET_HOME=$TARGET_HOME" \
      "VOID_SHOIZF_MASTER_LOG=$VOID_SHOIZF_MASTER_LOG" \
      bash "$SCRIPT_PATH" 2>&1 | tee -a "$MASTER_LOG_FILE"; then
      log "OK ${script_name}.sh success"
    else
      log "ERROR ${script_name}.sh failed (Root mode)"
    fi

  else
    # Run script as actual user with correct HOME + env
    if sudo -u "$TARGET_USER" -H env \
      "HOME=$TARGET_HOME" \
      "TARGET_USER=$TARGET_USER" \
      "TARGET_HOME=$TARGET_HOME" \
      "VOID_SHOIZF_MASTER_LOG=$VOID_SHOIZF_MASTER_LOG" \
      bash "$SCRIPT_PATH" 2>&1 | tee -a "$MASTER_LOG_FILE"; then
      log "OK ${script_name}.sh success"
    else
      log "ERROR ${script_name}.sh failed (User mode)"
    fi
  fi
done

log "✅ Installation Sequence Complete."
