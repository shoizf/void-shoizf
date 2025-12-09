#!/usr/bin/env bash
# installers/sddm_astronaut.sh — Install SDDM Astronaut theme and apply user-selected preset
# ROOT-SCRIPT (invoked by install.sh)
#
# ------------------------------------------------------
#  void-shoizf Script Version
# ------------------------------------------------------
#  Name: sddm_astronaut.sh
#  Version: 1.0.0
#  Updated: 2025-12-10
#  Purpose: Install SDDM Astronaut theme using user-selected preset.
# ------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# install.sh provides TMP_STAGING like:  ~/.cache/void-shoizf-selector
TMP_STAGING="${TMP_STAGING:-/tmp/void-shoizf-selector}"
THEME_CHOICE_FILE="$TMP_STAGING/theme"

if [ ! -f "$THEME_CHOICE_FILE" ]; then
    echo "ERROR: theme selection file missing. selector.sh didn't run."
    exit 1
fi

SELECTED_THEME="$(cat "$THEME_CHOICE_FILE")"

TARGET_HOME="${TARGET_HOME:-$HOME}"
LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

LOG_FILE="${VOID_SHOIZF_MASTER_LOG:-$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log}"
QUIET_MODE=${QUIET_MODE:-true}

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
    echo "$msg" >>"$LOG_FILE"
    [ "$QUIET_MODE" = false ] && echo "$msg"
}

pp() { echo -e "$*"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
ok()   { log "OK    $*"; }
error(){ log "ERROR $*"; exit 1; }

pp "▶ $SCRIPT_NAME"
info "Selected theme: $SELECTED_THEME"

# ------------------------------------------------------
# Clone to temp staging
# ------------------------------------------------------
TMP_CLONE="$TMP_STAGING/repo"
rm -rf "$TMP_CLONE"
mkdir -p "$TMP_CLONE"

info "Cloning SDDM Astronaut theme repo (shallow)..."
git clone --depth 1 https://github.com/Keyitdev/sddm-astronaut-theme.git "$TMP_CLONE"
ok "Theme repository cloned."

# ------------------------------------------------------
# Install files
# ------------------------------------------------------
THEME_BASE="/usr/share/sddm/themes"
THEME_DIR="$THEME_BASE/sddm-astronaut-theme"

rm -rf "$THEME_DIR"
mkdir -p "$THEME_BASE"

info "Copying theme into system directory..."
cp -r "$TMP_CLONE" "$THEME_DIR"
ok "Theme installed to $THEME_DIR"

# ------------------------------------------------------
# Apply preset (edit metadata.desktop)
# ------------------------------------------------------
METADATA="$THEME_DIR/metadata.desktop"
TARGET_PATH="Themes/${SELECTED_THEME}.conf"

if [ ! -f "$THEME_DIR/$TARGET_PATH" ]; then
    warn "Theme preset not found: $TARGET_PATH — using Jake the Dog instead."
    TARGET_PATH="Themes/jake_the_dog.conf"
fi

info "Editing metadata.desktop to set preset..."
sed -i "s|^ConfigFile=.*|ConfigFile=${TARGET_PATH}|" "$METADATA"
ok "Preset applied: $TARGET_PATH"

# ------------------------------------------------------
# Write SDDM config drop-in
# ------------------------------------------------------
mkdir -p /etc/sddm.conf.d

info "Writing /etc/sddm.conf.d/theme.conf"
cat >/etc/sddm.conf.d/theme.conf <<EOF
[Theme]
Current=sddm-astronaut-theme
EOF

info "Writing /etc/sddm.conf.d/virtualkbd.conf"
cat >/etc/sddm.conf.d/virtualkbd.conf <<EOF
[General]
InputMethod=qtvirtualkeyboard
EOF

ok "SDDM configuration written."

# ------------------------------------------------------
# Do NOT start SDDM now — just ensure symlink exists, then STOP the service
# ------------------------------------------------------
if [ ! -L /var/service/sddm ]; then
    ln -sf /etc/sv/sddm /var/service/
fi

# Immediately stop it to prevent popping up during install
sv down sddm || true
info "SDDM service prepared (enabled but stopped)."

# ------------------------------------------------------
# Cleanup
# ------------------------------------------------------
rm -rf "$TMP_STAGING"
ok "Temporary files cleaned."

log "✔ Finished $SCRIPT_NAME"
pp "✔ SDDM Astronaut theme installed using preset: $SELECTED_THEME"
exit 0
