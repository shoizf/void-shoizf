#!/usr/bin/env bash
# selector.sh — theme selector for SDDM Astronaut theme
# USER-SCRIPT (run before the root SDDM installer)
#
# ------------------------------------------------------
#  void-shoizf Script Version
# ------------------------------------------------------
#  Name: selector.sh
#  Version: 1.0.0
#  Updated: 2025-12-10
#  Purpose: Ask user which SDDM theme to use. Writes result to temp directory.
# ------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="selector"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# install.sh will export this
TMP_STAGING="${TMP_STAGING:-$HOME/.cache/void-shoizf-selector}"

mkdir -p "$TMP_STAGING"

LOG_FILE="$TMP_STAGING/${SCRIPT_NAME}-${TIMESTAMP}.log"
QUIET_MODE=${QUIET_MODE:-true}

log() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
    echo "$msg" >>"$LOG_FILE"
    [ "$QUIET_MODE" = false ] && echo "$msg"
}

pp() { echo -e "$*"; }

# ------------------------------------------------------
# THEMES (alphabetical, numbered automatically)
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

DEFAULT="jake_the_dog"

# ------------------------------------------------------
# UI + countdown
# ------------------------------------------------------

pp "▶ SDDM Theme Selection (default: $DEFAULT)"
pp ""
pp "Available themes:"

i=1
for t in "${THEMES[@]}"; do
    pp "  $i) $t"
    i=$((i+1))
done

pp ""
pp "Press [number + Enter] to choose theme."
pp "Timer: 15 seconds.  (p = pause, r = resume)"
pp ""

chosen=""
seconds=15
paused=false

while [ "$seconds" -gt 0 ]; do
    if ! $paused; then
        pp "Time remaining: ${seconds}s"
    fi

    read -t 1 -p "> " input || true

    if [ -n "${input:-}" ]; then
        case "$input" in
            p|P)
                paused=true
                pp "[Paused]"
                ;;
            r|R)
                paused=false
                pp "[Resumed]"
                ;;
            ''|*[!0-9]*)
                pp "Invalid entry."
                ;;
            *)
                idx=$((input))
                if [ "$idx" -ge 1 ] && [ "$idx" -le "${#THEMES[@]}" ]; then
                    chosen="${THEMES[$((idx-1))]}"
                    break
                else
                    pp "Invalid selection."
                fi
                ;;
        esac
    fi

    if ! $paused; then
        seconds=$((seconds - 1))
    fi
done

[ -z "$chosen" ] && chosen="$DEFAULT"

echo "$chosen" > "$TMP_STAGING/theme"

log "User selected: $chosen"
pp "Selected theme: $chosen"

exit 0
