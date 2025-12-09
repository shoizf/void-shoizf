#!/usr/bin/env bash
<<<<<<< HEAD
# sddm_theme_selector.sh — USER script
# VERSION: 1.0.0
# Handles SDDM theme choice BEFORE root installer applies it.

set -euo pipefail

SCRIPT_NAME="sddm_theme_selector"
=======
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
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

TARGET_USER="${TARGET_USER:-$USER}"
TARGET_HOME="${TARGET_HOME:-$HOME}"
<<<<<<< HEAD
LOG_FILE="${VOID_SHOIZF_MASTER_LOG:-/tmp/void_shoizf_master.log}"

# Temporary dir for storing user choice
TMP_DIR="/tmp/void-shoizf-sddm"
mkdir -p "$TMP_DIR"
SELECT_FILE="$TMP_DIR/theme_choice.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" >>"$LOG_FILE"
=======

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
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53
}

log "▶ Starting SDDM theme selector (User mode)"

# ------------------------------------------------------
<<<<<<< HEAD
# LIST OF THEMES (alphabetically sorted)
=======
# Theme list (alphabetical A → Z)
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53
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
<<<<<<< HEAD
# PRINT UI
# ------------------------------------------------------
clear
echo "▶ SDDM Theme Selection (default: ${DEFAULT_THEME})"
echo ""
echo "Available themes:"

=======
# UI HEADER
# ------------------------------------------------------

pp ""
pp "▶ SDDM Theme Selection (default: ${DEFAULT_THEME})"
pp ""
pp "Available themes:"
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53
i=1
for t in "${THEMES[@]}"; do
    echo "  ${i}) ${t}"
    i=$((i+1))
done
<<<<<<< HEAD

echo ""
echo "Press [number + Enter] to choose a theme."
echo "Timer: 15 seconds.   (p = pause, r = resume, ENTER = select default)"
echo ""

# ------------------------------------------------------
# INPUT + COUNTDOWN ENGINE (revised)
=======
pp ""
pp "Press [number + ENTER] to choose a theme."
pp "Timer: 15 seconds.  (p = pause, r = resume, ENTER = select default)"
pp ""

# ------------------------------------------------------
# INPUT + COUNTDOWN ENGINE
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53
# ------------------------------------------------------

CHOICE=""
SECONDS_LEFT=15
PAUSED=false

<<<<<<< HEAD
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
=======
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
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53
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

<<<<<<< HEAD
    # Auto default
=======
    # When timer hits zero → fallback to default
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53
    if [ "$SECONDS_LEFT" -le 0 ]; then
        CHOICE=""
        break
    fi
done

<<<<<<< HEAD
=======
# Restore terminal state
stty sane
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53
echo ""

# ------------------------------------------------------
# RESOLVE CHOICE
# ------------------------------------------------------

<<<<<<< HEAD
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
=======
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
>>>>>>> d925706bb48a288cb17c6e69f8ef5cf8b93c8e53

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
