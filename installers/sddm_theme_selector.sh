#!/usr/bin/env bash
# installers/sddm_theme_selector.sh — Interactive SDDM theme chooser
# Version: 1.2.0 (final stable)

set -euo pipefail

SCRIPT_NAME="sddm_theme_selector"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# ------------------------------------------------------
# Logging into master log
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
echo "▶ SDDM Theme Selection (default: jake_the_dog)"

# ------------------------------------------------------
# WORK DIRECTORY
# ------------------------------------------------------
THEME_DIR="$TARGET_HOME/.cache/void-shoizf-sddm-theme"

# Clean any previous leftover
rm -rf "$THEME_DIR"
mkdir -p "$THEME_DIR"

# ------------------------------------------------------
# 1. Clone theme repo
# ------------------------------------------------------
log "Cloning SDDM theme pack..."
git clone --depth=1 https://github.com/shoizf/void-niri-sddm-themes "$THEME_DIR" >> "$LOG_FILE" 2>&1

THEMES_DIR="$THEME_DIR/Themes"

if [ ! -d "$THEMES_DIR" ]; then
    echo "ERROR: theme directory missing after clone."
    log "ERROR: THEMES_DIR missing after clone."
    exit 1
fi

# ------------------------------------------------------
# 2. Collect themes
# ------------------------------------------------------
mapfile -t THEMES < <(ls "$THEMES_DIR" | sort)

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
echo "Timer: 15 seconds  (p = pause, r = resume, ENTER = default)"
echo ""

# ------------------------------------------------------
# INPUT ENGINE (digit buffer + ENTER)
# ------------------------------------------------------
SECONDS_LEFT=15
PAUSED=false
INPUT=""

# Instant key reads
stty -icanon -echo min 1 time 0

print_timer() {
    echo -ne "\rTime remaining: ${SECONDS_LEFT}s   "
}

while true; do
    print_timer

    if read -t 1 -n 1 key; then
        case "$key" in
            [0-9])
                INPUT="$INPUT$key"
                ;;
            p|P)
                PAUSED=true
                ;;
            r|R)
                PAUSED=false
                ;;
            "")
                break
                ;;
        esac
    fi

    # ENTER pressed AND we have input
    if [[ "$key" = "" && -n "$INPUT" ]]; then
        break
    fi

    if [ "$PAUSED" = false ]; then
        SECONDS_LEFT=$((SECONDS_LEFT - 1))
    fi

    if [ "$SECONDS_LEFT" -le 0 ]; then
        INPUT=""
        break
    fi
done

stty sane
echo ""

# ------------------------------------------------------
# RESOLVE SELECTION
# ------------------------------------------------------
if [[ -z "$INPUT" ]]; then
    CHOICE="$DEFAULT"
else
    if [[ "$INPUT" =~ ^[0-9]+$ ]] && [ "$INPUT" -ge 1 ] && [ "$INPUT" -le "${#THEMES[@]}" ]; then
        CHOICE="${THEMES[$((INPUT-1))]}"
    else
        CHOICE="$DEFAULT"
    fi
fi

echo "✔ Theme selected: $CHOICE"
log "Theme selected: $CHOICE"

# ------------------------------------------------------
# OUTPUT RESULT FOR NEXT SCRIPT
# ------------------------------------------------------
SELECTION_FILE="/tmp/void-shoizf-sddm-selection"
echo "$CHOICE" > "$SELECTION_FILE"

exit 0
