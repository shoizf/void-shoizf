#!/usr/bin/env bash
# =============================================================================
# hyprlock.sh — Installs and configures Hyprlock + Hypridle
# for Void Linux systems
#
# 📦 Generates hypridle.conf dynamically based on detected DPMS capabilities:
#   - Niri (via `niri msg outputs`)
#   - wlr-randr (for Wayland compositors)
#   - Fallback (no DPMS)
#
# 🧩 Includes smart reinstall behavior — only updates configs if changed.
# 🪵 Logs to ~/.local/log/void-shoizf/hyprlock.log
# =============================================================================

set -euo pipefail

# --- Path setup ---
REPO_DIR="$(dirname "$(realpath "$0")")/.."
CONFIG_DIR="$HOME/.config/hypr"
TEMPLATE_FILE="$REPO_DIR/configs/hypr/hypridle.conf.template"
HYPRIDLE_CONF="$CONFIG_DIR/hypridle.conf"
LOG_DIR="$HOME/.local/log/void-shoizf"
LOG_FILE="$LOG_DIR/hyprlock.log"

mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# --- Logging setup ---
exec > >(tee -a "$LOG_FILE") 2>&1
timestamp() { date +"[%Y-%m-%d %H:%M:%S]"; }
log() { echo "$(timestamp) $*"; }

log "🔒 Starting Hyprlock + Hypridle setup..."
log "------------------------------------------------------------"

# --- Step 1: Sanity checks for required helper scripts ---
HELPERS=(
  "$REPO_DIR/configs/hypr/music-info.sh"
  "$REPO_DIR/configs/hypr/music-progress.sh"
)

for helper in "${HELPERS[@]}"; do
  if [[ ! -f "$helper" ]]; then
    log "⚠️ Missing helper script: $helper"
  else
    chmod +x "$helper"
    log "✅ Found helper: $(basename "$helper")"
  fi
done

# --- Step 2: Sanity check for template file ---
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  log "❌ Missing template file: $TEMPLATE_FILE"
  exit 1
fi

# --- Step 3: Detect DPMS control method safely ---
log "🔍 Detecting DPMS control method..."

# Initialize variables safely (for set -u)
DPMS_METHOD="none"
SCREEN_OFF_CMD="echo '[hyprlock] Screen off skipped (no DPMS support detected)'"
SCREEN_ON_CMD="echo '[hyprlock] Screen on skipped (no DPMS support detected)'"

if command -v niri >/dev/null 2>&1 && niri msg outputs >/dev/null 2>&1; then
  DPMS_METHOD="niri"
  SCREEN_OFF_CMD="niri msg action power-off-monitors"
  SCREEN_ON_CMD=":" # auto handled on resume
  log "✅ Detected Niri DPMS control (niri msg is responsive)."

elif command -v wlr-randr >/dev/null 2>&1; then
  DPMS_METHOD="wlr"
  log "✅ Detected wlr-randr."

  if wlr-randr | grep -q 'Enabled: yes'; then
    SCREEN_OFF_CMD="/bin/bash -c 'wlr-randr | awk \"!/ / {print \\$1}\" | xargs -I{} wlr-randr --output {} --off'"
    SCREEN_ON_CMD="/bin/bash -c 'wlr-randr | awk \"!/ / {print \\$1}\" | xargs -I{} wlr-randr --output {} --on'"
    log "✅ Active displays detected for wlr-randr DPMS."
  else
    log "⚠️ No active display found via wlr-randr."
    SCREEN_OFF_CMD="echo '[hyprlock] Screen off skipped (no active wlr-randr display)'"
    SCREEN_ON_CMD="echo '[hyprlock] Screen on skipped (no active wlr-randr display)'"
  fi

else
  log "⚠️ No DPMS method detected (neither Niri nor wlr-randr)."
fi

# --- Step 4: Generate hypridle.conf from template with reinstall logic ---
log "🧩 Generating hypridle.conf from template..."

TMP_CONF="$(mktemp)"

sed -e "s#{{SCREEN_OFF_CMD}}#$SCREEN_OFF_CMD#g" \
  -e "s#{{SCREEN_ON_CMD}}#$SCREEN_ON_CMD#g" \
  "$TEMPLATE_FILE" >"$TMP_CONF"

# Smart reinstall: compare with existing config
if [[ -f "$HYPRIDLE_CONF" ]] && cmp -s "$TMP_CONF" "$HYPRIDLE_CONF"; then
  log "♻️ Existing hypridle.conf is identical — skipping reinstall."
  rm -f "$TMP_CONF"
else
  mv "$TMP_CONF" "$HYPRIDLE_CONF"
  log "✅ hypridle.conf installed/updated at $HYPRIDLE_CONF"
fi

# --- Step 5: Summary ---
log "------------------------------------------------------------"
log "🧩 DPMS Method: $DPMS_METHOD"
log "📄 Hypridle configuration: $HYPRIDLE_CONF"
log "📦 Log saved to: $LOG_FILE"
log "✅ Hyprlock setup completed successfully!"
log "------------------------------------------------------------"
