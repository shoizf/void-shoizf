#!/usr/bin/env bash
# installers/intel.sh — Intel GPU runtime checks & helpers (no package installs)
# ROOT-SCRIPT — executed via install.sh
#
# Responsibility: perform configuration and checks only.
# Package installation MUST be handled in installers/packages.sh.

set -euo pipefail

# ------------------------------------------------------
# 1. CONTEXT NORMALIZATION
# ------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Require TARGET_USER and TARGET_HOME exported by install.sh
if [ -z "${TARGET_USER:-}" ] || [ -z "${TARGET_HOME:-}" ]; then
  echo "ERROR: intel.sh requires TARGET_USER and TARGET_HOME exported by install.sh" >&2
  exit 1
fi

USER_HOME="$TARGET_HOME"

# Logging
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
  MASTER_MODE=true
else
  LOG_DIR="$USER_HOME/.local/log/void-shoizf"
  mkdir -p "$LOG_DIR"
  chown "$TARGET_USER:$TARGET_USER" "$LOG_DIR" || true
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
  MASTER_MODE=false
fi

QUIET_MODE=${QUIET_MODE:-true}

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

pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME (Root Mode)"
log "Context: TARGET_USER=$TARGET_USER, USER_HOME=$USER_HOME"

if [ "$EUID" -ne 0 ]; then
  error "intel.sh must be executed as root"
  pp "❌ intel: need root"
  exit 1
fi

# ------------------------------------------------------
# 2. PACKAGE RESPONSIBILITY NOTE
# ------------------------------------------------------
info "NOTE: packages for Intel (mesa-dri, xf86-video-intel, intel-media-driver, etc.) must be installed via packages.sh"
info "intel.sh will only run checks and non-invasive configuration."

# ------------------------------------------------------
# 3. Sanity checks
# ------------------------------------------------------

# Check presence of key libraries/binaries (warn-only)
checks=(
  "vainfo:vainfo"
  "modesetting driver via Xorg: /usr/lib/xorg/modules/drivers/modesetting_drv.so"
  "mesa (libGL):/usr/lib/libGL.so"
)

# Validate vainfo
if command -v vainfo >/dev/null 2>&1; then
  info "Running VAAPI check (vainfo)..."
  if ! vainfo >>"$LOG_FILE" 2>&1; then
    warn "vainfo returned an error; VAAPI may not be functional. Check intel-media-driver and libva."
  else
    ok "vainfo indicates VAAPI is functional"
  fi
else
  warn "vainfo not found — intel media/VAAPI packages may be missing (package: libva-utils / intel-media-driver)"
fi

# Check for Mesa GL (GLVND)
if compgen -G "/usr/lib/*/libGL.so" >/dev/null 2>&1 || [ -f "/usr/lib/libGL.so" ]; then
  ok "libGL (Mesa) appears present"
else
  warn "libGL not found — mesa packages may not be installed"
fi

# Check modesetting driver presence (Xorg)
if [ -f /usr/lib/xorg/modules/drivers/modesetting_drv.so ] || [ -f /usr/lib64/xorg/modules/drivers/modesetting_drv.so ]; then
  ok "modesetting Xorg driver present"
else
  warn "modesetting Xorg driver not found (xf86-video-intel / xorg-minimal may be missing)"
fi

# ------------------------------------------------------
# 4. Guidance for multilib / 32-bit libraries (warn-only)
# ------------------------------------------------------
if [ -d /usr/lib32 ] || compgen -G "/usr/lib32/*" >/dev/null 2>&1; then
  info "32-bit library path detected; ensure 32-bit mesa packages are present if you need 32-bit GL/Vulkan support"
else
  info "No 32-bit lib path detected; skipping 32-bit library checks"
fi

# ------------------------------------------------------
# 5. Finish
# ------------------------------------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
