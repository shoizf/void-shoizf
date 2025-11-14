#!/usr/bin/env bash
# installers/awww.sh — build & install awww and wallpaper-cycler

set -euo pipefail

# --- Logging setup ---
LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
SCRIPT_NAME="$(basename "$0" .sh)"

# Check if we're being run by the master installer
if [ -n "$VOID_SHOIZF_MASTER_LOG" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  # We are being run directly, create our own log
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}
# --- End Logging setup ---

log "▶ awww.sh starting"

if [ "$EUID" -eq 0 ]; then
  log "ERROR Do not run awww.sh as root. Exiting."
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$HOME/builds"
AWWW_DIR="$BUILD_DIR/awww"
mkdir -p "$BUILD_DIR"

DEPS=(gcc git pkg-config liblz4-devel wayland-devel wayland-protocols scdoc jq wget curl)
log "INFO Installing build deps: ${DEPS[*]}"
sudo xbps-install -Sy --yes "${DEPS[@]}" || log "WARN Some build deps may have failed"

# rustup / cargo
if ! command -v cargo >/dev/null 2>&1; then
  log "INFO Installing rustup for user"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  export PATH="$HOME/.cargo/bin:$PATH"
fi
log "INFO Using cargo at $(command -v cargo || echo 'not found')"

# Clone or update
if [ -d "$AWWW_DIR" ]; then
  log "INFO Updating existing awww repo"
  git -C "$AWWW_DIR" pull || log "WARN Failed to git pull awww"
else
  log "INFO Cloning awww repo"
  git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR" || log "WARN git clone failed"
fi

cd "$AWWW_DIR" || {
  log "ERROR awww dir missing"
  exit 1
}
log "INFO Building awww (release)"
if ! cargo build --release; then
  log "ERROR Cargo build failed"
  exit 1
fi

# Install binaries (requires sudo)
log "INFO Installing awww binaries to /usr/bin"
sudo cp -f target/release/awww /usr/bin/awww || log "WARN Failed to copy awww"
sudo cp -f target/release/awww-daemon /usr/bin/awww-daemon || log "WARN Failed to copy awww-daemon"

# Install wallpaper-cycler script to user bin
mkdir -p "$HOME/.local/bin"
cp -f "$REPO_ROOT/bin/wallpaper-cycler.sh" "$HOME/.local/bin/wallpaper-cycler.sh"
chmod +x "$HOME/.local/bin/wallpaper-cycler.sh"
log "OK Wallpaper cycler installed to $HOME/.local/bin"

rm -rf "$BUILD_DIR"
log "✅ awww.sh finished"
