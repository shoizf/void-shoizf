#!/usr/bin/env bash
# installers/awww.sh — build & install awww and wallpaper-cycler
# Run as USER (privileges dropped from install.sh)

set -euo pipefail

# --- 1. USER VALIDATION ---
if [ "$EUID" -eq 0 ]; then
  echo "❌ ERROR: awww.sh must be run as USER (not root)."
  exit 1
fi

# --- 2. LOGGING SETUP ---
LOG_BASE="$HOME/.local/state/void-shoizf/log"
mkdir -p "$LOG_BASE"
SCRIPT_NAME="$(basename "$0" .sh)"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_BASE/${SCRIPT_NAME}-${TIMESTAMP}.log"
  touch "$LOG_FILE"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

log "▶ awww.sh starting"

# --- 3. PATHS ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_DIR" == */installers ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  REPO_ROOT="$(pwd)"
fi

BIN_DIR="$HOME/.local/bin"
WALLPAPER_DIR="$HOME/.local/share/wallpapers"
BUILD_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/void-shoizf/builds/awww"

mkdir -p "$BIN_DIR" "$WALLPAPER_DIR" "$BUILD_CACHE"

# --- 4. RUST TOOLCHAIN SETUP (Local Override) ---
# We intentionally ignore system cargo. We want Rustup managed toolchain.
if [ ! -f "$HOME/.cargo/bin/cargo" ]; then
  log "INFO Local Cargo not found. Installing Rustup..."
  # -y: Disable confirmation prompts
  # --no-modify-path: We handle path sourcing manually to avoid shell profile mess
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
else
  log "INFO Local Rustup toolchain detected."
fi

# Force the script to use the local environment immediately
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
  log "INFO Sourced Rustup environment: $(command -v cargo)"
else
  log "WARN Could not source cargo env. Build might fail or use system cargo."
fi

# --- 5. BUILD AWWW ---
if [ -d "$BUILD_CACHE/.git" ]; then
  log "INFO Updating awww source..."
  git -C "$BUILD_CACHE" pull --progress
else
  log "INFO Cloning awww (Shallow clone)..."
  git clone --depth 1 --single-branch --progress https://codeberg.org/LGFae/awww.git "$BUILD_CACHE"
fi

log "INFO Building awww (release)..."
cd "$BUILD_CACHE"
# This will now definitely use the Rustup version because we sourced the env
cargo build --release

log "INFO Installing binaries to $BIN_DIR..."
install -D -m 755 target/release/awww "$BIN_DIR/awww"
install -D -m 755 target/release/awww-daemon "$BIN_DIR/awww-daemon"

# --- 6. INSTALL CYCLER SCRIPT ---
SRC_CYCLER="$REPO_ROOT/bin/wallpaper-cycler.sh"

if [ -f "$SRC_CYCLER" ]; then
  log "INFO Installing wallpaper-cycler.sh..."
  install -D -m 755 "$SRC_CYCLER" "$BIN_DIR/wallpaper-cycler.sh"
  log "OK Cycler installed"
else
  log "WARN Missing wallpaper-cycler.sh in repo!"
fi

# --- 7. CLEANUP ---
# rm -rf "$BUILD_CACHE/target"
log "✅ awww.sh finished"
