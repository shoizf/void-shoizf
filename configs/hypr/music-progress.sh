#!/usr/bin/env bash
# =============================================================================
# music-progress.sh — Displays playback progress bar and time
#
# 🎵 Compatible with playerctl (MPRIS)
# 🧠 Credits:
#   - Original EnviiLock by Kaushallrai
#   - Adapted for 'void-shoizf' — portable and cleaner output
# =============================================================================

set -euo pipefail

player=$(playerctl -l 2>/dev/null | head -n 1)

if [[ -z "$player" ]]; then
  echo "[ -------------------- ] 00:00 / 00:00"
  exit 0
fi

status=$(playerctl -p "$player" status 2>/dev/null || echo "Stopped")

if [[ "$status" != "Playing" ]]; then
  echo "[ -------------------- ] Paused"
  exit 0
fi

pos=$(playerctl -p "$player" position 2>/dev/null | cut -d '.' -f1)
length=$(playerctl -p "$player" metadata mpris:length 2>/dev/null | cut -d '.' -f1)
length=$((length / 1000000))

if [[ -z "$pos" || -z "$length" || "$length" -eq 0 ]]; then
  echo "[ -------------------- ] --:--"
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

format_time() {
  local total=$1
  local m=$((total / 60))
  local s=$((total % 60))
  printf "%02d:%02d" "$m" "$s"
}

pos_fmt=$(format_time "$pos")
len_fmt=$(format_time "$length")

echo "[ $bar ] $pos_fmt / $len_fmt"
