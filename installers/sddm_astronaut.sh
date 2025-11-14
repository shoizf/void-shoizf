#!/usr/bin/env bash
# installers/sddm_astronaut.sh — install SDDM astronaut theme and enable sddm

set -euo pipefail

# --- Logging setup ---
# Find the user's home dir for logging, even when run as root
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_HOME="$HOME"
fi

LOG_DIR="$USER_HOME/.local/log/void-shoizf"
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

log "▶ sddm_astronaut.sh starting"

if [ "$EUID" -ne 0 ]; then
  log "ERROR sddm_astronaut.sh must be run as root"
  exit 1
fi

xbps-install -Sy --yes sddm qt6-svg qt6-virtualkeyboard qt6-multimedia || log "WARN SDDM packages may have issues"

THEME_DIR="/usr/share/sddm/themes/sddm-astronaut-theme"
if [ -d "$THEME_DIR" ]; then
  log "INFO Theme dir exists — skipping clone"
else
  git clone -b master --depth 1 https://github.com/Keyitdev/sddm-astronaut-theme.git "$THEME_DIR" || log "WARN theme clone failed"
fi

cp -r "$THEME_DIR/Fonts/"* /usr/share/fonts/ || true

cat >/etc/sddm.conf <<EOF
[Theme]
Current=sddm-astronaut-theme
EOF

mkdir -p /etc/sddm.conf.d
cat >/etc/sddm.conf.d/virtualkbd.conf <<EOF
[General]
InputMethod=qtvirtualkeyboard
EOF

ln -sf /etc/sv/sddm /var/service/sddm || true
sv down sddm || true

log "✅ sddm_astronaut.sh finished"
