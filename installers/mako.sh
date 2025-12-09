#!/usr/bin/env bash
# installers/mako.sh — install & configure Mako notifications
# USER-SCRIPT (non-root; install.sh will run this as normal user)

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Prefer TARGET_* provided by install.sh
if [ -n "${TARGET_USER:-}" ] && [ -n "${TARGET_HOME:-}" ]; then
  TARGET_USER="${TARGET_USER}"
  TARGET_HOME="${TARGET_HOME}"
else
  TARGET_USER="$(logname 2>/dev/null || whoami)"
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || echo "$HOME")"
fi

# Master orchestrator log vs standalone log
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
  MASTER_MODE=true
else
  LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
  MASTER_MODE=false
fi

QUIET_MODE=${QUIET_MODE:-true}

# ------------------------------------------------------
# 2. LOGGING HELPERS
# ------------------------------------------------------
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >>"$LOG_FILE"
  if [ "$QUIET_MODE" = false ] && [ "$MASTER_MODE" = false ]; then
    echo "$msg"
  fi
}
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok() { log "OK    $*"; }
pp() { echo -e "$*"; }

# ------------------------------------------------------
# 3. STARTUP & VALIDATION
# ------------------------------------------------------
pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"
log "Context: TARGET_USER=${TARGET_USER}, TARGET_HOME=${TARGET_HOME}, MASTER_MODE=${MASTER_MODE}"

# Should not run as root
if [ "$EUID" -eq 0 ]; then
  error "mako.sh must NOT be run as root"
  pp "❌ ERROR: run as the target user; install.sh will call this correctly."
  exit 1
fi

# ------------------------------------------------------
# 4. CORE LOGIC — copy config (idempotent)
# ------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_CFG="$REPO_ROOT/configs/mako/config"
DEST_DIR="$TARGET_HOME/.config/mako"
DEST_CFG="$DEST_DIR/config"

if [ ! -f "$SOURCE_CFG" ]; then
  error "Source mako config missing in repo: $SOURCE_CFG"
  exit 1
fi

info "Installing mako config → $DEST_CFG"
mkdir -p "$DEST_DIR"

# write via tmpfile then move to avoid partial writes
TMP="$(mktemp)"
cp -f "$SOURCE_CFG" "$TMP"
install -D -m 644 "$TMP" "$DEST_CFG"
rm -f "$TMP"

# ensure ownership correct (best-effort)
chown "$TARGET_USER":"$TARGET_USER" "$DEST_CFG" 2>/dev/null || true

ok "Mako config copied to $DEST_CFG"

# Check whether mako binary exists and warn if not
if ! command -v mako >/dev/null 2>&1; then
  warn "mako not found on PATH — ensure 'mako' is installed (packages.sh)."
else
  info "mako binary detected: $(command -v mako)"
fi

info "Mako will autostart when Niri spawns it (add spawn-at-startup \"mako\" to Niri config if desired)."

# ------------------------------------------------------
# 5. END
# ------------------------------------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
