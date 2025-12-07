#!/usr/bin/env bash
# installers/audio.sh — Configure PipeWire + ALSA system-wide
# ROOT-SCRIPT — executed only by install.sh

set -euo pipefail

# ------------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Provided by install.sh for all ROOT scripts
TARGET_USER="${TARGET_USER:?missing TARGET_USER}"
TARGET_HOME="${TARGET_HOME:?missing TARGET_HOME}"
TARGET_GROUP="$(id -gn "$TARGET_USER")"

LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
chown -R "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.local/log"

# Master log or standalone fallback
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
    LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
    MASTER_MODE=true
else
    LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
    touch "$LOG_FILE"
    chown "$TARGET_USER:$TARGET_GROUP" "$LOG_FILE"
    MASTER_MODE=false
fi

QUIET_MODE="${QUIET_MODE:-true}"

# ------------------------------------------------------------
# 2. LOGGING HELPERS (safe with set -e)
# ------------------------------------------------------------
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
    echo "$msg" >>"$LOG_FILE"

    # Show only if not in master mode AND not quiet
    if [ "$MASTER_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
        echo "$msg"
    fi
}

info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok()    { log "OK    $*"; }
pp()    { echo -e "$*"; }

# ------------------------------------------------------------
# 3. HEADER
# ------------------------------------------------------------
pp ">> $SCRIPT_NAME"
log ">> Starting installer: $SCRIPT_NAME (root mode)"

# ------------------------------------------------------------
# 4. VALIDATION
# ------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    error "audio.sh must be executed as root (install.sh ROOT_SCRIPTS)"
    exit 1
fi

# ------------------------------------------------------------
# 5. CORE AUDIO LOGIC — System-wide PipeWire ALSA Setup
# ------------------------------------------------------------

# Locations where PipeWire installs ALSA compatibility config
PW_ALSA_SRC="/usr/share/alsa/alsa.conf.d/50-pipewire.conf"

# Where system ALSA config must go
PW_ALSA_DEST="/etc/alsa/conf.d/50-pipewire.conf"

info "Configuring ALSA to use PipeWire routing"

# 5.1 Validate source exists
if [ ! -f "$PW_ALSA_SRC" ]; then
    warn "Missing ALSA PipeWire template: $PW_ALSA_SRC"
    warn "PipeWire packages may not be installed yet"
    warn "Skipping audio configuration safely"
    exit 0
fi

# 5.2 Ensure /etc/alsa/conf.d exists
mkdir -p /etc/alsa/conf.d

# 5.3 If an existing non-symlink config exists, back it up
if [ -e "$PW_ALSA_DEST" ] && [ ! -L "$PW_ALSA_DEST" ]; then
    BACKUP="${PW_ALSA_DEST}.bak-${TIMESTAMP}"
    info "Backing up existing ALSA config to: $BACKUP"
    mv "$PW_ALSA_DEST" "$BACKUP"
fi

# 5.4 Create/replace symlink
ln -sf "$PW_ALSA_SRC" "$PW_ALSA_DEST"
ok "ALSA is now routed through PipeWire"
info "Linked destination: $PW_ALSA_DEST -> $PW_ALSA_SRC"

# 5.5 Optional service check
if [ ! -d /etc/sv/pipewire ]; then
    warn "PipeWire runit service not found; it may start via user session instead"
fi

# ------------------------------------------------------------
# 6. END
# ------------------------------------------------------------
log "Finished installer: $SCRIPT_NAME"
pp "Done: $SCRIPT_NAME"
exit 0
