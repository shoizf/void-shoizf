#!/usr/bin/env bash
# music-progress.sh
# =============================================================================
# Playback progress bar for hyprlock
# Adapted from Kaushallrai's work: https://github.com/Kaushallrai/hyprlock.git
# =============================================================================

set -euo pipefail

player=$(playerctl -l 2>/dev/null | head -n1 || true)
if [[ -z "$player" ]]; then
  echo ""
  exit 0
fi

status=$(playerctl -p "$player" status 2>/dev/null || echo "Stopped")
if [[ "$status" != "Playing" ]]; then
  echo ""
  exit 0
fi

pos=$(playerctl -p "$player" position 2>/dev/null | cut -d'.' -f1 || echo 0)
length=$(playerctl -p "$player" metadata mpris:length 2>/dev/null | cut -d'.' -f1 || echo 0)
length=$((length / 1000000))

if [[ "$length" -eq 0 ]]; then
  echo ""
  exit 0
fi

bar_length=20
progress=$((pos * bar_length / length))
bar=""
for ((i = 0; i < bar_length; i++)); do
  if ((i < progress)); then
    bar+="▓"
  else
    bar+="-"
  fi
done

format_time() { printf "%02d:%02d" "$(($1 / 60))" "$(($1 % 60))"; }

echo "[ $bar ] $(format_time "$pos") / $(format_time "$length")"
