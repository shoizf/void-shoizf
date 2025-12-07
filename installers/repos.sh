#!/usr/bin/env bash
# installers/repos.sh — enable official Void repos + Makrennel Hyprland repo

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Detect correct HOME when executed via sudo
if [ -n "${SUDO_USER:-}" ]; then
  TARGET_USER="$SUDO_USER"
  TARGET_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  TARGET_USER="$(whoami)"
  TARGET_HOME="$HOME"
fi

# Fallback
[ -z "${TARGET_HOME:-}" ] && TARGET_HOME="$HOME"

# Logging
LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
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
  if [ "$QUIET_MODE" = false ]; then echo "$msg"; fi
}

info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok()   { log "OK    $*"; }

pp() { echo -e "$*"; }

# ------------------------------------------------------
# 3. STARTUP HEADER
# ------------------------------------------------------

pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"
info "User: $TARGET_USER | Home: $TARGET_HOME"

# ------------------------------------------------------
# 4. VALIDATION (ROOT-ONLY)
# ------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
  error "This script must be executed as ROOT"
  pp "❌ ERROR: installers/repos.sh must be run as root (via install.sh ROOT_SCRIPTS)."
  exit 1
fi

# ------------------------------------------------------
# 5. ENABLE OFFICIAL VOID REPOSITORIES
# ------------------------------------------------------

info "Installing official Void repository packages…"

OFFICIAL_REPO_PKGS=(
  void-repo-nonfree
  void-repo-multilib
  void-repo-multilib-nonfree
  void-repo-debug
)

if xbps-install -y "${OFFICIAL_REPO_PKGS[@]}"; then
  ok "Official Void repos installed (or already present)"
else
  warn "Failed to install one or more official repo packages"
fi

# ------------------------------------------------------
# 6. CONFIGURE MAKRENNEL HYPRLAND REPOSITORY
# ------------------------------------------------------

HYPR_REPO_CONF="/etc/xbps.d/hyprland-void.conf"
HYPR_REPO_LINE="repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc"

info "Configuring Hyprland (Makrennel) repository…"

if [ -f "$HYPR_REPO_CONF" ]; then
  info "Makrennel repo already present at $HYPR_REPO_CONF"
else
  echo "$HYPR_REPO_LINE" >"$HYPR_REPO_CONF"
  ok "Makrennel repo added to $HYPR_REPO_CONF"
fi

# ------------------------------------------------------
# 7. SYNC + ACCEPT FINGERPRINTS (NON-INTERACTIVE)
# ------------------------------------------------------

info "Syncing all XBPS repositories (auto-accept fingerprints)…"

if xbps-install -Sy <<< "yes"; then
  ok "Repository sync + fingerprint acceptance complete"
else
  warn "xbps-install -Sy reported issues — check network or repo status"
fi

# ------------------------------------------------------
# 8. END
# ------------------------------------------------------

log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
