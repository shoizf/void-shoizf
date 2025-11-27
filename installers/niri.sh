#!/usr/bin/env bash
# installers/niri.sh — install Niri session file & user config
# MIXED-SCRIPT:
# - Must run as *root* to install session file
# - Writes config into target user's HOME

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Determine target user (passed in by install.sh)
TARGET_USER=${1:-$(logname 2>/dev/null || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

# Logging must happen in *target* user's home, even if root
LOG_DIR="$TARGET_USER_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
  MASTER_MODE=true
else
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
  if [ "$QUIET_MODE" = false ]; then
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
log "▶ Starting installer: $SCRIPT_NAME"
info "Target user: $TARGET_USER"
info "Target home: $TARGET_USER_HOME"

# ------------------------------------------------------
# 4. VALIDATION
# ------------------------------------------------------

# Ensure script runs as root — required for writing to /usr/share
if [ "$EUID" -ne 0 ]; then
  error "Script must be executed as root (install.sh ROOT_SCRIPTS)"
  exit 1
fi

# Validate account entry
if ! getent passwd "$TARGET_USER" >/dev/null; then
  error "User '$TARGET_USER' does not exist"
  exit 1
fi

# ------------------------------------------------------
# 5. CORE LOGIC
# ------------------------------------------------------

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

SRC_CONFIG="$REPO_ROOT/configs/niri/config.kdl"
DEST_CONFIG="$TARGET_USER_HOME/.config/niri/config.kdl"
SESSION_FILE="/usr/share/wayland-sessions/niri.desktop"

# --- Copy config.kdl ---
if [ ! -f "$SRC_CONFIG" ]; then
  error "Missing config: $SRC_CONFIG"
  exit 1
fi

info "Copying niri config → $DEST_CONFIG"
mkdir -p "$(dirname "$DEST_CONFIG")"
cp -f "$SRC_CONFIG" "$DEST_CONFIG"
chown "$TARGET_USER":"$TARGET_USER" "$DEST_CONFIG" || warn "Could not change ownership"
ok "Config installed"

# --- Install session file ---
info "Installing Niri session file → $SESSION_FILE"

cat >"$SESSION_FILE" <<EOF
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=dbus-run-session -- /usr/bin/niri
Type=WaylandSession
DesktopNames=niri
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=niri
XDG_CURRENT_DESKTOP=niri
X-GDM-SessionType=wayland
Categories=System;Utility;X-Wayland;
EOF

# Ensure correct permissions
chmod 644 "$SESSION_FILE"

ok "Session file created"

# ------------------------------------------------------
# 6. END
# ------------------------------------------------------

log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
