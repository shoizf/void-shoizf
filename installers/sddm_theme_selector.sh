#!/usr/bin/env bash
# installers/sddm_theme_selector.sh
# USER-SCRIPT (run as non-root, uses no sudo)
#
# ------------------------------------------------------
#  void-shoizf Script Version
# ------------------------------------------------------
#  Name: sddm_theme_selector.sh
#  Version: 1.1.0
#  Updated: 2025-12-09
#  Purpose: Collect theme choice BEFORE the root script runs.
#           Writes result to temp file for sddm_astronaut.sh.
# ------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

TARGET_USER="${TARGET_USER:-$USER}"
TARGET_HOME="${TARGET_HOME:-$HOME}"

LOG_FILE="${VOID_SHOIZF_MASTER_LOG}"

# Temp directory for selector
TMP_DIR="$TARGET_HOME/.cache/void-shoizf-sddm"
mkdir -p "$TMP_DIR"
CHOICE_FILE="$TMP_DIR/theme_choice.txt"

# Final script will remove the folder entirely.
# We only write here.

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
    echo "$msg" >> "$LOG_FILE"
}

pp() { echo -e "$*"; }

# ------------------------------------------------------
# Theme list (alphabetical A → Z)
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
# UI HEADER
# ------------------------------------------------------

pp ""
pp "▶ SDDM Theme Selection (default: ${DEFAULT_THEME})"
pp ""
pp "Available themes:"
i=1
for t in "${THEMES[@]}"; do
    pp "  $i) $t"
    i=$((i+1))
done
pp ""
pp "Press [number + ENTER] to choose a theme."
pp "Timer: 15 seconds.  (p = pause, r = resume, ENTER = select default)"
pp ""

# ------------------------------------------------------
# INPUT + COUNTDOWN ENGINE
# ------------------------------------------------------

CHOICE=""
SECONDS_LEFT=15
PAUSED=false

# Disable buffering for instant input
stty -icanon -echo min 1 time 0

print_timer() {
    echo -ne "\rTime remaining: ${SECONDS_LEFT}s  "
}

while true; do
    print_timer

    # Read one character if available
    if read -t 1 -n 1 key; then
        case "$key" in
            [0-9])
                CHOICE="$key"
                ;;
            p|P)
                PAUSED=true
                ;;
            r|R)
                PAUSED=false
                ;;
            "")
                # ENTER = default
                CHOICE=""
                ;;
        esac

        # User selected a number
        if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
            break
        fi

        # ENTER key pressed → default
        if [ "$key" = "" ]; then
            break
        fi
    fi

    # Countdown logic
    if [ "$PAUSED" = false ]; then
        SECONDS_LEFT=$((SECONDS_LEFT - 1))
    fi

    # When timer hits zero → fallback to default
    if [ "$SECONDS_LEFT" -le 0 ]; then
        CHOICE=""
        break
    fi
done

# Restore terminal state
stty sane
echo ""

# ------------------------------------------------------
# RESOLVE CHOICE
# ------------------------------------------------------

if [[ -z "$CHOICE" ]]; then
    THEME="$DEFAULT_THEME"
else
    INDEX=$((CHOICE - 1))

    if (( INDEX < 0 || INDEX >= ${#THEMES[@]} )); then
        THEME="$DEFAULT_THEME"
    else
        THEME="${THEMES[$INDEX]}"
    fi
fi

# ------------------------------------------------------
# WRITE RESULT
# ------------------------------------------------------

echo "$THEME" > "$CHOICE_FILE"
log "Selected theme: $THEME (saved to $CHOICE_FILE)"

pp "✔ Theme selected: $THEME"
pp ""

exit 0
