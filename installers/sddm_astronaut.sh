#!/usr/bin/env bash
# installers/sddm_astronaut.sh — Install + activate chosen theme
# Version: 1.2.0 (final stable)

set -euo pipefail

SCRIPT_NAME="sddm_astronaut"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Logging
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
    LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
    LOG_FILE="/var/log/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" >> "$LOG_FILE"
}

echo ""
echo "▶ Applying SDDM Theme"

# ------------------------------------------------------
# READ SELECTION
# ------------------------------------------------------
SELECTION_FILE="/tmp/void-shoizf-sddm-selection"

if [ ! -f "$SELECTION_FILE" ]; then
    echo "ERROR: No theme selection file!"
    log "ERROR: Missing $SELECTION_FILE"
    exit 1
fi

THEME_CHOICE="$(cat "$SELECTION_FILE")"
log "Theme choice: $THEME_CHOICE"

# ------------------------------------------------------
# INSTALLATION PATHS
# ------------------------------------------------------
THEME_SRC="$TARGET_HOME/.cache/void-shoizf-sddm-theme/Themes/$THEME_CHOICE"
THEME_DEST="/usr/share/sddm/themes/$THEME_CHOICE"

if [ ! -d "$THEME_SRC" ]; then
    echo "ERROR: Theme directory missing: $THEME_SRC"
    log "ERROR Theme source missing"
    exit 1
fi

# ------------------------------------------------------
# COPY THEME INTO SYSTEM
# ------------------------------------------------------
mkdir -p /usr/share/sddm/themes
rm -rf "$THEME_DEST"
cp -a "$THEME_SRC" "$THEME_DEST"

log "Theme copied to $THEME_DEST"

# ------------------------------------------------------
# ENABLE SDDM
# ------------------------------------------------------
SV="/etc/sv/sddm"
SRV="/etc/runit/runsvdir/default/sddm"

ln -sf "$SV" "$SRV"
log "Linked sddm → runsvdir"

# Immediately stop it so user stays in TTY
sv down sddm || true
log "Forced sddm down after linking"

# ------------------------------------------------------
# CLEANUP
# ------------------------------------------------------
rm -rf "$TARGET_HOME/.cache/void-shoizf-sddm-theme"
rm -f "$SELECTION_FILE"

log "Cleanup complete"
echo "✔ SDDM theme installed and prepared."

exit 0
