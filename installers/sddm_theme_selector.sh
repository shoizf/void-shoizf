#!/usr/bin/env bash
# sddm_theme_selector.sh — USER script
# VERSION: 1.0.0
# Handles SDDM theme choice BEFORE root installer applies it.

set -euo pipefail

SCRIPT_NAME="sddm_theme_selector"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

TARGET_USER="${TARGET_USER:-$USER}"
TARGET_HOME="${TARGET_HOME:-$HOME}"
LOG_FILE="${VOID_SHOIZF_MASTER_LOG:-/tmp/void_shoizf_master.log}"

# Temporary dir for storing user choice
TMP_DIR="/tmp/void-shoizf-sddm"
mkdir -p "$TMP_DIR"
SELECT_FILE="$TMP_DIR/theme_choice.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" >>"$LOG_FILE"
}

log "▶ Starting SDDM theme selector (User mode)"

# ------------------------------------------------------
# LIST OF THEMES (alphabetically sorted)
# ------------------------------------------------------
THEMES=(
    "astronaut"
    "black_hole"
    "cyberpunk"
    "hyprland_kath"
    "jake_the_dog"
    "japanese_aesthetic"
    "pixel_sakura"
    "pixel_sakura_static"
    "post-apocalyptic_hacker"
    "purple_leaves"
)

DEFAULT_THEME="jake_the_dog"

# ------------------------------------------------------
# PRINT UI
# ------------------------------------------------------
clear
echo "▶ SDDM Theme Selection (default: ${DEFAULT_THEME})"
echo ""
echo "Available themes:"

i=1
for t in "${THEMES[@]}"; do
    echo "  ${i}) ${t}"
    i=$((i+1))
done

echo ""
echo "Press [number + Enter] to choose a theme."
echo "Timer: 15 seconds.   (p = pause, r = resume, ENTER = select default)"
echo ""

# ------------------------------------------------------
# INPUT + COUNTDOWN ENGINE (revised)
# ------------------------------------------------------

CHOICE=""
SECONDS_LEFT=15
PAUSED=false

print_timer() {
    echo -ne "\rTime remaining: ${SECONDS_LEFT}s "
}

while true; do
    print_timer

    # Read a full line (supports multi-digit); timeout 1s
    if read -t 1 -r key; then
        case "$key" in
            "" )
                # ENTER = default
                CHOICE=""
                break
                ;;

            [0-9]* )
                # Multi-digit ok
                if [[ "$key" =~ ^[0-9]+$ ]]; then
                    CHOICE="$key"
                    break
                fi
                ;;

            p|P )
                PAUSED=true
                ;;

            r|R )
                PAUSED=false
                ;;

            * )
                echo -ne "\rInvalid input.               "
                ;;
        esac
    fi

    # Countdown logic
    if [ "$PAUSED" = false ]; then
        SECONDS_LEFT=$((SECONDS_LEFT - 1))
    fi

    # Auto default
    if [ "$SECONDS_LEFT" -le 0 ]; then
        CHOICE=""
        break
    fi
done

echo ""

# ------------------------------------------------------
# RESOLVE CHOICE
# ------------------------------------------------------

if [ -z "$CHOICE" ]; then
    FINAL_THEME="$DEFAULT_THEME"
else
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#THEMES[@]}" ]; then
        echo "Invalid choice. Using default."
        FINAL_THEME="$DEFAULT_THEME"
    else
        FINAL_THEME="${THEMES[$((CHOICE - 1))]}"
    fi
fi

echo "✔ Theme selected: ${FINAL_THEME}"
log "Selected theme: ${FINAL_THEME}"

# ------------------------------------------------------
# WRITE RESULT TO TEMP FILE
# ------------------------------------------------------

echo "$FINAL_THEME" > "$SELECT_FILE"
chmod 600 "$SELECT_FILE"
log "Theme written to: $SELECT_FILE"

log "✔ Selector complete."
exit 0
