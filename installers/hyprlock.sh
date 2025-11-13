#!/usr/bin/env bash
if [[ -f "$SRC_BG" ]]; then
  install -m 0644 -D "$SRC_BG" "$DEST_BG"
  chown "$TARGET_USER":"$TARGET_USER" "$DEST_BG"
  log "✅ Hyprlock background installed (force replaced): $DEST_BG"
else
  log "⚠️ Background image not found in repo: $SRC_BG"
fi

# --- DPMS detection: only attempt if we are interactive (no parent mode) ---
DPMS_METHOD="none"
SCREEN_OFF_CMD="echo '[hyprlock] Screen off skipped (no DPMS detected)'"
SCREEN_ON_CMD="echo '[hyprlock] Screen on skipped (no DPMS detected)'"

if [[ $PARENT_MODE -eq 0 && -t 1 ]]; then
  if command -v niri >/dev/null 2>&1 && niri msg outputs >/dev/null 2>&1; then
    DPMS_METHOD="niri"
    SCREEN_OFF_CMD="niri msg action power-off-monitors"
    SCREEN_ON_CMD=":"
    log "Detected Niri DPMS control."
  elif command -v wlr-randr >/dev/null 2>&1; then
    DPMS_METHOD="wlr-randr"
    SCREEN_OFF_CMD="/bin/bash -c 'wlr-randr | awk \"!/ / {print \\$1}\" | xargs -r -I{} wlr-randr --output {} --off'"
    SCREEN_ON_CMD="/bin/bash -c 'wlr-randr | awk \"!/ / {print \\$1}\" | xargs -r -I{} wlr-randr --output {} --on'"
    log "Detected wlr-randr DPMS control."
  else
    log "No DPMS method detected; using no-op commands."
  fi
else
  log "Parent/install.sh mode or non-interactive: using no-op DPMS commands to avoid blanking."
fi

# --- Suspend command detection ---
if command -v zzz >/dev/null 2>&1; then
  SUSPEND_CMD="zzz"
elif command -v loginctl >/dev/null 2>&1; then
  SUSPEND_CMD="loginctl suspend"
else
  SUSPEND_CMD="echo '[hyprlock] Suspend skipped (no zzz/loginctl)'"
fi

# --- Generate hypridle.conf from template ---
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  log "❌ Template missing: $TEMPLATE_FILE"
  exit 1
fi

TMP_CONF=$(mktemp)
sed -e "s#__SCREEN_OFF_CMD__#${SCREEN_OFF_CMD}#g" \
  -e "s#__SCREEN_ON_CMD__#${SCREEN_ON_CMD}#g" \
  -e "s#__SUSPEND_CMD__#${SUSPEND_CMD}#g" \
  "$TEMPLATE_FILE" >"$TMP_CONF"

mkdir -p "$(dirname "$HYPRIDLE_CONF")"
if [[ -f "$HYPRIDLE_CONF" ]] && cmp -s "$TMP_CONF" "$HYPRIDLE_CONF"; then
  log "hypridle.conf unchanged; skipping update."
  rm -f "$TMP_CONF"
else
  mv "$TMP_CONF" "$HYPRIDLE_CONF"
  chown "$TARGET_USER":"$TARGET_USER" "$HYPRIDLE_CONF"
  log "Installed hypridle.conf -> $HYPRIDLE_CONF"
fi

log "Setup complete. DPMS: $DPMS_METHOD. Background: $DEST_BG"
