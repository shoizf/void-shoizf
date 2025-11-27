#!/usr/bin/env bash
# installers/hyprlock.sh — Install hyprlock/hypridle configs, assets & zzz sudo rule
# ROOT-SCRIPT — executed via install.sh

set -euo pipefail

# ------------------------------------------------------
# 1. CONTEXT NORMALIZATION (never use $HOME)
# ------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# install.sh exports TARGET_USER / TARGET_HOME for all ROOT scripts
if [ -z "${TARGET_USER:-}" ] || [ -z "${TARGET_HOME:-}" ]; then
  echo "❌ ERROR: hyprlock.sh requires TARGET_USER and TARGET_HOME from install.sh" >&2
  exit 1
fi

USER_HOME="$TARGET_HOME"

# Determine logging file
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
  MASTER_MODE=true
else
  LOG_DIR="$USER_HOME/.local/log/void-shoizf"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
  MASTER_MODE=false
fi

QUIET_MODE=${QUIET_MODE:-true}

# ------------------------------------------------------
# 2. LOGGING FUNCTIONS
# ------------------------------------------------------
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >>"$LOG_FILE"
  if [ "$QUIET_MODE" = false ] && [ "$MASTER_MODE" = false ]; then echo "$msg"; fi
}
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok() { log "OK    $*"; }
pp() { echo -e "$*"; }

# ------------------------------------------------------
# 3. VALIDATION
# ------------------------------------------------------
pp "▶ $SCRIPT_NAME"
log "▶ Starting hyprlock installer for $TARGET_USER ($USER_HOME)"

if [ "$EUID" -ne 0 ]; then
  error "hyprlock.sh must run as root"
  exit 1
fi

if [ ! -d "$USER_HOME" ]; then
  error "User home directory not found: $USER_HOME"
  exit 1
fi

# ------------------------------------------------------
# 4. SUDOERS FOR zzz
# ------------------------------------------------------
SUDO_FILE="/etc/sudoers.d/void-shoizf-zzz"
SUDO_RULE="${TARGET_USER} ALL=(ALL) NOPASSWD: /usr/bin/zzz"

info "Configuring sudoers rule for /usr/bin/zzz…"

echo "$SUDO_RULE" >"$SUDO_FILE"
chmod 440 "$SUDO_FILE"

# Validate
if ! visudo -c >/dev/null 2>&1; then
  error "sudoers syntax invalid! Removing $SUDO_FILE to avoid lockout."
  rm -f "$SUDO_FILE"
  exit 1
fi

ok "sudoers validated and installed"

# ------------------------------------------------------
# 5. PATH SETUP
# ------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HYPR_CONFIG_DIR="$USER_HOME/.config/hypr"
ASSETS_DIR="$USER_HOME/.local/share/hypr/assets"
BIN_DIR="$USER_HOME/.local/bin"

mkdir -p "$HYPR_CONFIG_DIR" "$ASSETS_DIR" "$BIN_DIR"
chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config" "$USER_HOME/.local"

# ------------------------------------------------------
# 6. Install hyprlock + hypridle packages
# ------------------------------------------------------
info "Installing hyprlock + hypridle…"
if xbps-install -Sy --yes hyprlock hypridle >>"$LOG_FILE" 2>&1; then
  ok "hyprlock/hypridle installed"
else
  warn "Installation encountered issues"
fi

# ------------------------------------------------------
# 7. Install helper scripts
# ------------------------------------------------------
HELPERS=(battery-status.sh music-info.sh music-progress.sh shoizf-lock)

info "Installing helper scripts…"
for h in "${HELPERS[@]}"; do
  SRC="$REPO_ROOT/bin/$h"
  DEST="$BIN_DIR/$h"
  if [ -f "$SRC" ]; then
    install -D -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$SRC" "$DEST"
    ok "Installed $h"
  else
    warn "Missing: $SRC"
  fi
done

# ------------------------------------------------------
# 8. Assets
# ------------------------------------------------------
SRC_BG="$REPO_ROOT/configs/hypr/assets/hyprlockbg.jpg"
DEST_BG="$ASSETS_DIR/hyprlockbg.jpg"

if [ -f "$SRC_BG" ]; then
  install -D -m 644 -o "$TARGET_USER" -g "$TARGET_USER" "$SRC_BG" "$DEST_BG"
  ok "Installed background image"
else
  warn "Missing background asset"
fi

# ------------------------------------------------------
# 9. hyprlock.conf (replace bg path)
# ------------------------------------------------------
SRC_LOCK="$REPO_ROOT/configs/hypr/hyprlock.conf"
DEST_LOCK="$HYPR_CONFIG_DIR/hyprlock.conf"

if [ -f "$SRC_LOCK" ]; then
  sed "s|~/.local/share/hypr/assets/hyprlockbg.jpg|$DEST_BG|" "$SRC_LOCK" |
    install -D -m 644 -o "$TARGET_USER" -g "$TARGET_USER" /dev/stdin "$DEST_LOCK"
  ok "Installed hyprlock.conf"
else
  warn "hyprlock.conf missing"
fi

# ------------------------------------------------------
# 10. hypridle.conf (template → rendered)
# ------------------------------------------------------
SRC_IDLE="$REPO_ROOT/configs/hypr/hypridle.conf.template"
DEST_IDLE="$HYPR_CONFIG_DIR/hypridle.conf"

if [ -f "$SRC_IDLE" ]; then
  sed \
    -e "s|__SCREEN_OFF_CMD__|niri msg action power-off-monitors|g" \
    -e "s|__SCREEN_ON_CMD__|:|g" \
    -e "s|__SUSPEND_CMD__|/usr/bin/zzz|g" \
    "$SRC_IDLE" |
    install -D -m 644 -o "$TARGET_USER" -g "$TARGET_USER" /dev/stdin "$DEST_IDLE"
  ok "Generated hypridle.conf"
else
  warn "Idle template missing"
fi

# ------------------------------------------------------
# 11. FINISH
# ------------------------------------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
