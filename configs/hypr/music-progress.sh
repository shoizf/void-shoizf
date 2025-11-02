#!/bin/bash
#
# music-progress.sh
#
# Original "EnviiLock" theme and logic by Kaushallrai
# https://github.com/Kaushallrai/hyprlock
#
# Modified for 'shoizf' setup:
# - Flexible player: Grabs the *first* ("oldest") player.
# - Fixed bug in 'mpris:length' command.
#

# Get the first player listed by playerctl (the "oldest" one)
player=$(playerctl -l 2>/dev/null | head -n 1)

if [ -z "$player" ]; then
  echo "[ -------------------- ] Paused"
  exit
fi

# Get status from that specific "oldest" player
status=$(playerctl -p "$player" status 2>/dev/null)

if [[ "$status" != "Playing" ]]; then
  echo "[ -------------------- ] Paused"
  exit
fi

# Get metadata from that specific "oldest" player
pos=$(playerctl -p "$player" position 2>/dev/null | cut -d '.' -f1)

# This line is now fixed to correctly target the player
length=$(playerctl -p "$player" metadata mpris:length 2>/dev/null | cut -d '.' -f1)
length=$((length / 1000000))

if [[ -z "$pos" || -z "$length" || "$length" -eq 0 ]]; then
  echo "[ -------------------- ] --:--"
  exit
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
  local m=$(($1 / 60))
  local s=$(($1 % 60))
  printf "%02d:%02d" "$m" "$s"
}

pos_fmt=$(format_time "$pos")
len_fmt=$(format_time "$length")

echo "[ $bar ] $pos_fmt / $len_fmt"
