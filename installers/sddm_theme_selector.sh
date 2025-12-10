#!/usr/bin/env bash
# installers/sddm_theme_selector.sh — Interactive SDDM theme chooser
# Version: 1.0.0

set -euo pipefail

SCRIPT_NAME="sddm_theme_selector"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Logging (honors shared MASTER log file)
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
    LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
    LOG_FILE="$HOME/.local/log/void-shoizf/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" >> "$LOG_FILE"
}

echo ""
echo "▶ SDDM Theme Selection (default: jake_the_dog)"

# Path where themes live after cloning
THEME_DIR="$TARGET_HOME/.cache/void-shoizf-sddm-theme"
THEMES_DIR="$THEME_DIR/Themes"

if [ ! -d "$THEMES_DIR" ]; then
    log "ERROR theme directory missing: $THEMES_DIR"
    echo "ERROR: theme selection file missing, selector.sh didn’t run."
    exit 1
fi

# Gather theme names
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
echo "Press [number + Enter] to choose theme."
echo "Timer: 15 seconds.  (p = pause, r = resume, ENTER = select default)"
echo ""

# ------------------------------------------------------
# INPUT ENGINE (2-key model: number + ENTER)
# ------------------------------------------------------

SECONDS_LEFT=15
PAUSED=false
INPUT=""

# Disable canonical mode for instant key reading
stty -icanon -echo min 1 time 0

print_timer() {
    echo -ne "\rTime remaining: ${SECONDS_LEFT}s   "
}

while true; do
    print_timer

    # Read one key if available
    if read -t 1 -n 1 key; then
        case "$key" in
            [0-9])
                INPUT="$INPUT$key"  # Append digit
                ;;
            p|P)
                PAUSED=true
                ;;
            r|R)
                PAUSED=false
                ;;
            "")
                # ENTER pressed
                break
                ;;
        esac
    fi

    # ENTER after typing at least one digit
    if [[ "$key" = "" && -n "$INPUT" ]]; then
        break
    fi

    # Countdown
    if [ "$PAUSED" = false ]; then
        SECONDS_LEFT=$((SECONDS_LEFT - 1))
    fi

    if [ "$SECONDS_LEFT" -le 0 ]; then
        INPUT=""
        break
    fi
done

# Restore terminal state
stty sane
echo ""

# ------------------------------------------------------
# RESOLVE SELECTION
# ------------------------------------------------------

if [[ -z "$INPUT" ]]; then
    CHOICE="$DEFAULT"
else
    # Validate index
    if [[ "$INPUT" =~ ^[0-9]+$ ]] && [ "$INPUT" -ge 1 ] && [ "$INPUT" -le "${#THEMES[@]}" ]; then
        CHOICE="${THEMES[$((INPUT-1))]}"
    else
        CHOICE="$DEFAULT"
    fi
fi

echo "✔ Theme selected: $CHOICE"
log "Selected theme: $CHOICE"

# Write result to a temp file for sddm_astronaut.sh
RESULT_FILE="/tmp/void-shoizf-sddm-selection"
echo "$CHOICE" > "$RESULT_FILE"

exit 0
