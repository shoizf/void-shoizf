#!/usr/bin/env bash
# installers/sddm_astronaut.sh — Install + configure SDDM Astronaut theme
# ROOT-SCRIPT (run via install.sh with sudo)

set -euo pipefail

# ------------------------------------------------------
#  void-shoizf Script Version
# ------------------------------------------------------
#  Name: sddm_astronaut.sh
#  Version: 2.0.0
#  Updated: 2025-12-09
#  Purpose:
#    • Install SDDM astronaut theme (Keyitdev)
#    • Apply user-selected preset (from helper script)
#    • Prevent SDDM startup during installation
#    • Clean temporary selector directory fully
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

TARGET_USER="${TARGET_USER:?Must be provided}"
TARGET_HOME="${TARGET_HOME:?Must be provided}"
LOG_FILE="${VOID_SHOIZF_MASTER_LOG:?Missing MASTER LOG}"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
    echo "$msg" >> "$LOG_FILE"
}
pp() { echo -e "$*"; }

pp "▶ $SCRIPT_NAME"
log "▶ Starting $SCRIPT_NAME for user $TARGET_USER"

# --------------------------------------------------------------------
# 1. Load theme choice from helper script
# --------------------------------------------------------------------

TMP_DIR="$TARGET_HOME/.cache/void-shoizf-sddm"
CHOICE_FILE="$TMP_DIR/theme_choice.txt"

if [ ! -f "$CHOICE_FILE" ]; then
    log "WARN No selector choice found — using default jake_the_dog"
    THEME_CHOICE="jake_the_dog"
else
    THEME_CHOICE="$(cat "$CHOICE_FILE" | tr -d '[:space:]')"
fi

log "INFO Theme to apply: $THEME_CHOICE"

# --------------------------------------------------------------------
# 2. Clone theme repo into a safe temp directory
# --------------------------------------------------------------------

WORK_DIR="$(mktemp -d /tmp/sddmtheme.XXXX)"
THEME_CLONE="$WORK_DIR/theme"

log "INFO Cloning SDDM Astronaut theme repository"
git clone --depth 1 https://github.com/Keyitdev/sddm-astronaut-theme.git "$THEME_CLONE" >>"$LOG_FILE" 2>&1

# --------------------------------------------------------------------
# 3. Install theme to system directory
# --------------------------------------------------------------------

THEME_BASE="/usr/share/sddm/themes"
THEME_NAME="sddm-astronaut-theme"
THEME_DEST="$THEME_BASE/$THEME_NAME"

log "INFO Installing theme to $THEME_DEST"

rm -rf "$THEME_DEST"
mkdir -p "$THEME_DEST"
cp -r "$THEME_CLONE/"* "$THEME_DEST/"

log "OK Theme installed"

# --------------------------------------------------------------------
# 4. Install theme fonts
# --------------------------------------------------------------------

if [ -d "$THEME_DEST/Fonts" ]; then
    log "INFO Installing fonts"
    cp -r "$THEME_DEST/Fonts/"* /usr/share/fonts/
    fc-cache -f >>"$LOG_FILE" 2>&1
    log "OK Fonts installed"
else
    log "WARN Theme contains no fonts directory"
fi

# --------------------------------------------------------------------
# 5. Apply selected preset (metadata.desktop modification)
# --------------------------------------------------------------------

METADATA="$THEME_DEST/metadata.desktop"
TARGET_PATH="Themes/${THEME_CHOICE}.conf"

if [ ! -f "$THEME_DEST/$TARGET_PATH" ]; then
    log "WARN Selected preset not found, reverting to jake_the_dog"
    THEME_CHOICE="jake_the_dog"
    TARGET_PATH="Themes/jake_the_dog.conf"
fi

log "INFO Applying preset: $THEME_CHOICE"

sed -i "s|^ConfigFile=.*|ConfigFile=$TARGET_PATH|" "$METADATA"

log "OK metadata.desktop updated"

# --------------------------------------------------------------------
# 6. Write SDDM Config
# --------------------------------------------------------------------

mkdir -p /etc/sddm.conf.d

# Main theme config
tee /etc/sddm.conf >/dev/null <<EOF
[Theme]
Current=$THEME_NAME
ConfigFile=$TARGET_PATH
EOF

# Virtual keyboard config
tee /etc/sddm.conf.d/virtualkbd.conf >/dev/null <<EOF
[General]
InputMethod=qtvirtualkeyboard
EOF

log "OK SDDM configuration files written"

# --------------------------------------------------------------------
# 7. Prevent SDDM from activating during installation
# --------------------------------------------------------------------

SV_DIR="/etc/sv/sddm"
RUNIT_DIR="/etc/runit/runsvdir/default"

log "INFO Enabling SDDM service symlink"
ln -sf "$SV_DIR" "$RUNIT_DIR/sddm"

log "INFO Forcing sddm to stay DOWN during install"
sv down sddm 2>/dev/null || true

log "OK SDDM is enabled but held down"

# --------------------------------------------------------------------
# 8. Cleanup temporary files from selector + clone directory
# --------------------------------------------------------------------

log "INFO Cleaning selector temporary directory"
rm -rf "$TMP_DIR"

log "INFO Removing work directory"
rm -rf "$WORK_DIR"

log "OK Cleanup completed"

# --------------------------------------------------------------------
# END
# --------------------------------------------------------------------

pp "✔ $SCRIPT_NAME done (Theme: $THEME_CHOICE)"
log "✔ Finished $SCRIPT_NAME"

exit 0
