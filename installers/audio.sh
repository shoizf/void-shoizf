#!/usr/bin/env bash
# installers/audio.sh — configure PipeWire & ALSA
# ROOT-SCRIPT (must be executed as root by install.sh)

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# install.sh guarantees these are passed for ROOT scripts
TARGET_USER="${TARGET_USER:?missing TARGET_USER}"
TARGET_HOME="${TARGET_HOME:?missing TARGET_HOME}"

LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

# Master log injected by install.sh OR standalone log
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
  MASTER_MODE=true
else
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
# 3. STARTUP HEADER
# ------------------------------------------------------

pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME (root mode)"

# ------------------------------------------------------
# 4. VALIDATION
# ------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
  error "audio.sh must be run as root (install.sh ROOT_SCRIPTS)"
  exit 1
fi

# ------------------------------------------------------
# 5. CORE LOGIC
# ------------------------------------------------------

ALSA_SRC="/usr/share/alsa/alsa.conf.d/50-pipewire.conf"
ALSA_DEST="/etc/alsa/conf.d/50-pipewire.conf"

if [ ! -f "$ALSA_SRC" ]; then
  warn "Missing ALSA/PipeWire source at $ALSA_SRC — ensure packages installed"
else
  info "Configuring ALSA to use PipeWire…"
  mkdir -p /etc/alsa/conf.d

  # Already correctly linked?
  if [ -L "$ALSA_DEST" ] && [ "$(readlink -f "$ALSA_DEST")" = "$ALSA_SRC" ]; then
    info "ALSA already configured ($ALSA_DEST → $ALSA_SRC)"
    ok "No changes needed"
  else
    # Backup old config
    if [ -e "$ALSA_DEST" ] && [ ! -L "$ALSA_DEST" ]; then
      BACKUP="${ALSA_DEST}.bak-${TIMESTAMP}"
      info "Found non-symlink config — backing up to $BACKUP"
      mv "$ALSA_DEST" "$BACKUP" || warn "Could not backup existing config"
    fi

    ln -sf "$ALSA_SRC" "$ALSA_DEST"
    ok "Linked $ALSA_DEST → $ALSA_SRC"
  fi
fi

# ------------------------------------------------------
# 6. END
# ------------------------------------------------------

log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
