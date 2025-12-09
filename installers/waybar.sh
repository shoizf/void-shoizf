#!/usr/bin/env bash
# installers/waybar.sh — Deploy Waybar config (no package installs)
# USER-SCRIPT — must be run as the target desktop user (not root)

# ------------------------------------------------------
#  void-shoizf Script Version
# ------------------------------------------------------
#  Name:    waybar.sh
#  Version: 1.0.0
#  Updated: 2025-12-09
#  Purpose: Safely deploy Waybar configs from repo → $HOME/.config/waybar
# ------------------------------------------------------

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Resolve target user & home (even when invoked via sudo)
if [ -n "${SUDO_USER:-}" ]; then
  TARGET_USER="$SUDO_USER"
  TARGET_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  TARGET_USER="$(whoami)"
  TARGET_HOME="$HOME"
fi

# Fallback safety: if getent failed for some reason
if [ -z "${TARGET_HOME:-}" ]; then
  echo "[$SCRIPT_NAME] ERROR: could not resolve TARGET_HOME for user '$TARGET_USER'" >&2
  exit 1
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
# 2. LOGGING HELPERS
# ------------------------------------------------------
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >>"$LOG_FILE"
  if [ "$QUIET_MODE" = false ]; then
    echo "$msg"
  fi
}

info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok()    { log "OK    $*"; }
pp()    { echo -e "$*"; }

pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"
info "Target user:  $TARGET_USER"
info "Target home:  $TARGET_HOME"

# Warn if run as root (but do NOT hard-fail — install.sh might still call it)
if [ "$EUID" -eq 0 ]; then
  warn "$SCRIPT_NAME is meant to run as a NORMAL USER, not root. Config may end up in /root."
fi

# ------------------------------------------------------
# 3. REPO ROOT & SOURCE CONFIG
# ------------------------------------------------------
# Always resolve relative to this script's location, not cwd
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SRC="$REPO_ROOT/configs/waybar"
WAYBAR_DEST="$TARGET_HOME/.config/waybar"

info "Repo root:     $REPO_ROOT"
info "Config source: $CONFIG_SRC"
info "Config target: $WAYBAR_DEST"

# 3.1: Verify source config exists
if [ ! -d "$CONFIG_SRC" ]; then
  error "Waybar config source missing: $CONFIG_SRC"
  pp "❌ waybar: config source not found. Did you clone the repo correctly?"
  exit 1
fi

# ------------------------------------------------------
# 4. BACKUP & DEPLOY
# ------------------------------------------------------
# 4.1: Backup existing config (if any)
if [ -d "$WAYBAR_DEST" ]; then
  BACKUP="${WAYBAR_DEST}.bak-${TIMESTAMP}"
  info "Existing Waybar config found; backing up → $BACKUP"
  mv "$WAYBAR_DEST" "$BACKUP"
  ok "Backup complete"
fi

# 4.2: Deploy new config (copy everything, including dotfiles)
info "Installing Waybar configuration…"
mkdir -p "$(dirname "$WAYBAR_DEST")"
mkdir -p "$WAYBAR_DEST"

# Use cp -a to preserve structure and include dotfiles
cp -a "$CONFIG_SRC/." "$WAYBAR_DEST/"

# 4.3: Ensure ownership
if id "$TARGET_USER" >/dev/null 2>&1; then
  chown -R "$TARGET_USER:$TARGET_USER" "$WAYBAR_DEST" || warn "Failed to chown $WAYBAR_DEST (check permissions)"
else
  warn "User '$TARGET_USER' not found in system accounts; skipping chown"
fi

# 4.4: Validate essential files
if [ ! -f "$WAYBAR_DEST/config.jsonc" ] && [ ! -f "$WAYBAR_DEST/config" ]; then
  error "Waybar config missing after installation (no config.jsonc or config)"
  pp "❌ waybar: config.jsonc not found in $WAYBAR_DEST"
  exit 1
fi

ok "Waybar configuration deployed successfully"

# ------------------------------------------------------
# 5. RUNTIME CHECKS (NON-FATAL)
# ------------------------------------------------------
# 5.1: Waybar binary presence
if ! command -v waybar >/dev/null 2>&1; then
  warn "Waybar binary not found — verify Waybar package installation"
else
  info "Waybar binary detected: $(command -v waybar)"
fi

# 5.2: NetworkManager CLI (for network module)
if ! command -v nmcli >/dev/null 2>&1; then
  warn "nmcli missing — Waybar network module may not work (package: NetworkManager)"
fi

# 5.3: Power profiles daemon (for battery/perf module)
if ! command -v powerprofilesctl >/dev/null 2>&1; then
  warn "powerprofilesctl missing — power profile indicator may not work (package: power-profiles-daemon)"
fi

# ------------------------------------------------------
# 6. END
# ------------------------------------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"

exit 0
