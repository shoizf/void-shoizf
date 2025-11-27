#!/usr/bin/env bash
# installers/waybar.sh — Copy Waybar config (packages installed via packages.sh)
# USER-SCRIPT (run as normal user; uses sudo internally)

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Correct user resolution (even when run under sudo)
if [ -n "${SUDO_USER:-}" ]; then
  TARGET_USER="$SUDO_USER"
  TARGET_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  TARGET_USER="${1:-$(whoami)}"
  TARGET_HOME="${2:-$HOME}"
fi

LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

QUIET_MODE=${QUIET_MODE:-true}

# ------------------------------------------------------
# 2. LOGGING FUNCTIONS
# ------------------------------------------------------

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >>"$LOG_FILE"
  [ "$QUIET_MODE" = false ] && echo "$msg"
}
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok() { log "OK    $*"; }
pp() { echo -e "$*"; }

# ------------------------------------------------------
# 3. STARTUP
# ------------------------------------------------------

pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"
info "Target user:  $TARGET_USER"
info "Target home:  $TARGET_HOME"

# User-script — warn if executed incorrectly
if [ "$EUID" -eq 0 ]; then
  warn "$SCRIPT_NAME is meant to run as a USER, not root."
fi

# ------------------------------------------------------
# 4. CORE LOGIC — CONFIG DEPLOYMENT ONLY
# ------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SRC="$REPO_ROOT/configs/waybar"
WAYBAR_DEST="$TARGET_HOME/.config/waybar"

# 4.1: Verify config source exists
if [ ! -d "$CONFIG_SRC" ]; then
  error "Waybar config source missing: $CONFIG_SRC"
  exit 1
fi

# 4.2: Backup old config
if [ -d "$WAYBAR_DEST" ]; then
  BACKUP="${WAYBAR_DEST}.bak-${TIMESTAMP}"
  info "Backing up existing config → $BACKUP"
  mv "$WAYBAR_DEST" "$BACKUP"
  ok "Backup complete"
fi

# 4.3: Install new config safely
info "Installing Waybar configuration..."

mkdir -p "$WAYBAR_DEST"
TMP="$(mktemp -d)"

cp -r "$CONFIG_SRC/"* "$TMP/" 2>/dev/null

shopt -s dotglob nullglob
mv "$TMP"/* "$WAYBAR_DEST/"
shopt -u dotglob nullglob

rm -rf "$TMP"
chown -R "$TARGET_USER:$TARGET_USER" "$WAYBAR_DEST"

# 4.4: Validate config presence
if [ ! -f "$WAYBAR_DEST/config.jsonc" ] && [ ! -f "$WAYBAR_DEST/config" ]; then
  error "Waybar config missing after installation"
  exit 1
fi

ok "Waybar configuration installed successfully"

# ------------------------------------------------------
# 5. RUNTIME CHECKS
# ------------------------------------------------------

# 5.1: Check Waybar binary
if ! command -v waybar >/dev/null 2>&1; then
  warn "Waybar binary not found — verify package installation"
else
  info "Waybar binary detected"
fi

# 5.2: Check NetworkManager availability (common module)
if ! command -v nmcli >/dev/null 2>&1; then
  warn "nmcli missing — Waybar network module may not work"
fi

# 5.3: Check power-profiles-daemon availability
if ! command -v powerprofilesctl >/dev/null 2>&1; then
  warn "powerprofilesctl missing — power profile indicator may not work"
fi

# ------------------------------------------------------
# 6. END
# ------------------------------------------------------

log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
