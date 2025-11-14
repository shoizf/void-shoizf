#!/usr/bin/env bash
# installers/hyprlock.sh — install hyprlock/hypridle configs and helpers
# Note: Always run hyprlock setup on both VM and physical machines (no skip)

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

log "▶ hyprlock.sh starting"

if [ "$EUID" -eq 0 ]; then
  log "ERROR hyprlock.sh must NOT be run as root. Exiting."
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_FILE="$REPO_ROOT/configs/hypr/hypridle.conf.template"
HYPR_CONFIG_DIR="$HOME/.config/hypr"
HYPRIDLE_CONF="$HYPR_CONFIG_DIR/hypridle.conf"
SRC_BG="$REPO_ROOT/configs/hypr/assets/hyprlockbg.jpg"
DEST_BG="$HOME/.local/share/hypr/assets/hyprlockbg.jpg"

mkdir -p "$(dirname "$HYPRIDLE_CONF")" "$HOME/.local/share/hypr/assets"

# Copy background image (force replace)
if [ -f "$SRC_BG" ]; then
  install -m 0644 -D "$SRC_BG" "$DEST_BG"
  chown "$USER":"$USER" "$DEST_BG" || true
  log "OK Hyprlock background installed: $DEST_BG"
else
  log "WARN Hyprlock background missing: $SRC_BG"
fi

# Informational VM detection if available
if [ -f "$REPO_ROOT/utils/is_vm.sh" ]; then
  source "$REPO_ROOT/utils/is_vm.sh" || true
  log "INFO VM detection for hyprlock: IS_VM=${IS_VM}"
else
  log "INFO VM detection utility not found for hyprlock"
fi

# Detect DPMS / suspend utilities (informational only)
DPMS_METHOD="none"
SCREEN_OFF_CMD="echo '[hyprlock] Screen off skipped (no DPMS detected)'"
SCREEN_ON_CMD=":"
SUSPEND_CMD="echo '[hyprlock] Suspend skipped (no suspend tool)'"

if command -v niri >/dev/null 2>&1 && niri msg outputs >/dev/null 2>&1; then
  DPMS_METHOD="niri"
  SCREEN_OFF_CMD="niri msg action power-off-monitors"
  SCREEN_ON_CMD=":"
  log "INFO Detected Niri DPMS control"
elif command -v wlr-randr >/dev/null 2>&1; then
  DPMS_METHOD="wlr-randr"
  SCREEN_OFF_CMD="/bin/bash -c 'wlr-randr | awk \"!/ / {print \\\$$1}\" | xargs -r -I{} wlr-randr --output {} --off'"
  SCREEN_ON_CMD="/bin/bash -c 'wlr-randr | awk \"!/ / {print \\\$$1}\" | xargs -r -I{} wlr-randr --output {} --on'"
  log "INFO Detected wlr-randr DPMS control"
else
  log "INFO No DPMS control detected; hyprlock will use safe defaults"
fi

if command -v zzz >/dev/null 2>&1; then
  SUSPEND_CMD="zzz"
elif command -v loginctl >/dev/null 2>&1; then
  SUSPEND_CMD="loginctl suspend"
fi

# Generate hypridle.conf from template
if [ -f "$TEMPLATE_FILE" ]; then
  TMP_CONF="$(mktemp)"
  sed -e "s#__SCREEN_OFF_CMD__#${SCREEN_OFF_CMD}#g" \
    -e "s#__SCREEN_ON_CMD__#${SCREEN_ON_CMD}#g" \
    -e "s#__SUSPEND_CMD__#${SUSPEND_CMD}#g" \
    "$TEMPLATE_FILE" >"$TMP_CONF"

  if [ -f "$HYPRIDLE_CONF" ] && cmp -s "$TMP_CONF" "$HYPRIDLE_CONF"; then
    rm -f "$TMP_CONF"
    log "OK hypridle.conf unchanged; no update needed"
  else
    mv "$TMP_CONF" "$HYPRIDLE_CONF"
    chown "$USER":"$USER" "$HYPRIDLE_CONF" || true
    log "OK hypridle.conf installed -> $HYPRIDLE_CONF"
  fi
else
  log "ERROR hypridle template missing: $TEMPLATE_FILE"
fi

log "✅ hyprlock.sh finished (always applied)"
