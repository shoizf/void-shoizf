#!/usr/bin/env bash
# installers/sddm_astronaut.sh — install SDDM astronaut theme and enable sddm

set -euo pipefail

LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
MASTER_LOG="$LOG_DIR/master-install.log"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE" >>"$MASTER_LOG"
}

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
