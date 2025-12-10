#!/usr/bin/env bash
# installers/sddm_theme_selector.sh — Interactive SDDM theme chooser
# Version: 1.0.1
# Updated: 2025-12-10

set -euo pipefail

SCRIPT_NAME="sddm_theme_selector"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# ------------------------------------------------------
# LOGGING
# ------------------------------------------------------
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
    LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
    LOG_FILE="$HOME/.local/log/void-shoizf/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" >> "$LOG_FILE"
}

echo ""
echo "▶ SDDM Theme Selection"
echo "Default: jake_the_dog"

# ------------------------------------------------------
# VALIDATE TEMP CLONE DIR EXISTS (created by sddm_astronaut.sh)
# ------------------------------------------------------
THEME_DIR="$TARGET_HOME/.cache/void-shoizf-sddm-theme"
THEMES_DIR="$THEME_DIR/Themes"

if [ ! -d "$THEMES_DIR" ]; then
    log "ERROR: Missing theme directory: $THEMES_DIR"
    echo "ERROR: sddm theme directory missing. Clone step did not run."
    exit 1
fi

# ------------------------------------------------------
# LOAD THEMES
# ------------------------------------------------------
mapfile -t THEMES < <(ls "$THEMES_DIR" | sed 's/.conf$//' | sort)

echo ""
echo "Available themes:"
i=1
for t in "${THEMES[@]}"; do
    echo "  $i) $t"
    i=$((i+1))
done

DEFAULT="jake_the_dog"

echo ""
echo "Select by typing NUMBER + ENTER"
echo "Controls: [p] pause | [r] resume | ENTER = default"
echo ""

# ------------------------------------------------------
# INPUT ENGINE — multi-digit + ENTER confirm
# ------------------------------------------------------
SECONDS_LEFT=15
PAUSED=false
INPUT=""

# Disable canonical mode for instant key reads
stty -icanon -echo min 1 time 0

print_timer() {
    echo -ne "\rTime remaining: ${SECONDS_LEFT}s   "
}

while true; do
    print_timer

    if read -t 1 -n 1 key; then
        case "$key" in
            [0-9])
                INPUT+="$key"   # append digits
                ;;
            p|P)
                PAUSED=true
                ;;
            r|R)
                PAUSED=false
                ;;
            "")
                # ENTER pressed → stop
                break
                ;;
        esac
    fi

    # Countdown tick
    if [ "$PAUSED" = false ]; then
        SECONDS_LEFT=$((SECONDS_LEFT - 1))
    fi

    if [ "$SECONDS_LEFT" -le 0 ]; then
        INPUT=""
        break
    fi
done

# Restore terminal settings
stty sane
echo ""

# ------------------------------------------------------
# RESOLVE SELECTION
# ------------------------------------------------------
if [[ -z "$INPUT" ]]; then
    CHOICE="$DEFAULT"
else
    if [[ "$INPUT" =~ ^[0-9]+$ ]] \
       && [ "$INPUT" -ge 1 ] \
       && [ "$INPUT" -le "${#THEMES[@]}" ]; then
        CHOICE="${THEMES[$((INPUT-1))]}"
    else
        CHOICE="$DEFAULT"
    fi
fi

echo "✔ Theme selected: $CHOICE"
log "Theme selected: $CHOICE"

# ------------------------------------------------------
# WRITE SELECTION FOR ROOT SCRIPT
# ------------------------------------------------------
RESULT_FILE="/tmp/void-shoizf-sddm-selection"
echo "$CHOICE" > "$RESULT_FILE"

exit 0
