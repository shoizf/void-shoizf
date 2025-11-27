#!/usr/bin/env bash
# installers/awww.sh — build & install awww + wallpaper-cycler
# USER-SCRIPT — must never run as root.

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Prefer TARGET_* env from install.sh; otherwise infer user/home safely
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
# 2. LOGGING FUNCTIONS
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

# Must not run as root (this is a user-level installer)
if [ "$EUID" -eq 0 ]; then
  error "awww.sh must NOT be executed as root"
  pp "❌ ERROR: Run this script as the target user (install.sh will call it correctly)."
  exit 1
fi

# Ensure TARGET_HOME exists and is writable
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
  error "Target home directory missing or invalid: $TARGET_HOME"
  exit 1
fi

# ------------------------------------------------------
# 4. PATHS
# ------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BIN_DIR="$TARGET_HOME/.local/bin"
WALLPAPER_DIR="$TARGET_HOME/.local/share/wallpapers"
BUILD_CACHE="${XDG_CACHE_HOME:-$TARGET_HOME/.cache}/void-shoizf/builds/awww"

mkdir -p "$BIN_DIR" "$WALLPAPER_DIR" "$BUILD_CACHE"

# ------------------------------------------------------
# 5. VERIFY TOOLCHAIN (cargo)
# ------------------------------------------------------

# Prefer user-local cargo (from Rustup) installed into TARGET_HOME
CARGO_PATH="$TARGET_HOME/.cargo/bin/cargo"

if command -v cargo >/dev/null 2>&1; then
  info "cargo detected on PATH -> $(command -v cargo)"
elif [ -x "$CARGO_PATH" ]; then
  # shellcheck disable=SC1091
  if [ -f "$TARGET_HOME/.cargo/env" ]; then
    # Load the user's cargo env so cargo is available in this shell
    # (this file should be present when rustup was installed into the user's home)
    # shellcheck disable=SC1091
    source "$TARGET_HOME/.cargo/env"
    info "Sourced $TARGET_HOME/.cargo/env (cargo now at $(command -v cargo 2>/dev/null || echo unknown))"
  else
    warn "Found cargo binary at $CARGO_PATH but no $TARGET_HOME/.cargo/env to source"
  fi
else
  warn "cargo not detected. Ensure 'cargo' (Rust) is installed by packages.sh before running awww.sh."
fi

if ! command -v cargo >/dev/null 2>&1; then
  error "cargo not available — cannot build awww. Aborting."
  exit 1
fi

# ------------------------------------------------------
# 6. FETCH SOURCE (clone or update)
# ------------------------------------------------------

if [ -d "$BUILD_CACHE/.git" ]; then
  info "Updating existing awww source in $BUILD_CACHE"
  if git -C "$BUILD_CACHE" pull --ff-only >>"$LOG_FILE" 2>&1; then
    ok "awww source updated"
  else
    warn "git pull failed (see log). Continuing to attempt build with current sources."
  fi
else
  info "Cloning awww repository to $BUILD_CACHE"
  if git clone --depth 1 --single-branch https://codeberg.org/LGFae/awww.git "$BUILD_CACHE" >>"$LOG_FILE" 2>&1; then
    ok "awww cloned"
  else
    error "Failed to clone awww repository (network or git issue). See $LOG_FILE"
    exit 1
  fi
fi

# ------------------------------------------------------
# 7. BUILD (release) — fail loudly on errors
# ------------------------------------------------------

info "Building awww (release) in $BUILD_CACHE"
(
  cd "$BUILD_CACHE"
  if cargo build --release >>"$LOG_FILE" 2>&1; then
    ok "cargo build succeeded"
  else
    error "cargo build failed — check $LOG_FILE for details"
    exit 1
  fi
)

# Ensure expected binaries exist
AWWW_BIN="$BUILD_CACHE/target/release/awww"
AWWW_DAEMON_BIN="$BUILD_CACHE/target/release/awww-daemon"

if [ ! -x "$AWWW_BIN" ] || [ ! -x "$AWWW_DAEMON_BIN" ]; then
  error "Expected build outputs missing: $AWWW_BIN or $AWWW_DAEMON_BIN"
  exit 1
fi

# ------------------------------------------------------
# 8. INSTALL BINARIES (atomic)
# ------------------------------------------------------

info "Installing awww binaries to $BIN_DIR"

# Use a temp dir then move to avoid partial state
TMP_DIR="$(mktemp -d "${BUILD_CACHE}/tmp.install.XXXX")"
install -D -m 755 "$AWWW_BIN" "$TMP_DIR/awww"
install -D -m 755 "$AWWW_DAEMON_BIN" "$TMP_DIR/awww-daemon"

# Move into place
mv "$TMP_DIR"/awww "$BIN_DIR/awww"
mv "$TMP_DIR"/awww-daemon "$BIN_DIR/awww-daemon"
rmdir "$TMP_DIR" 2>/dev/null || true

ok "Installed: $BIN_DIR/awww and $BIN_DIR/awww-daemon"

# Ensure ownership (should be running as target user already; this ensures correct ownership if not)
chown "$TARGET_USER":"$TARGET_USER" "$BIN_DIR/awww" "$BIN_DIR/awww-daemon" 2>/dev/null || true

# ------------------------------------------------------
# 9. INSTALL WALLPAPER CYCLER SCRIPT
# ------------------------------------------------------

SRC_CYCLER="$REPO_ROOT/bin/wallpaper-cycler.sh"
DEST_CYCLER="$BIN_DIR/wallpaper-cycler.sh"

if [ -f "$SRC_CYCLER" ]; then
  info "Installing wallpaper-cycler.sh → $DEST_CYCLER"
  install -D -m 755 "$SRC_CYCLER" "$DEST_CYCLER"
  chown "$TARGET_USER":"$TARGET_USER" "$DEST_CYCLER" 2>/dev/null || true
  ok "Wallpaper cycler installed"
else
  warn "wallpaper-cycler.sh missing in repo ($SRC_CYCLER)"
fi

# ------------------------------------------------------
# 10. END
# ------------------------------------------------------

log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
