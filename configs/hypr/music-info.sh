#!/bin/bash
#
# music-info.sh
#
# Original "EnviiLock" theme and logic by Kaushallrai
# https://github.com/Kaushallrai/hyprlock
#
# Modified for 'shoizf' setup:
# - Flexible player: Grabs the *first* ("oldest") player from playerctl.
#

# Get the first player listed by playerctl (the "oldest" one)
player=$(playerctl -l 2>/dev/null | head -n 1)

if [ -z "$player" ]; then
  echo "Nothing Playing"
  exit
fi

# Get metadata from that specific "oldest" player
artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
title=$(playerctl -p "$player" metadata title 2>/dev/null)

if [[ -n "$artist" && -n "$title" ]]; then
  # Format it like the EnviiLock theme
  artist_spaced=$(echo " $artist" | sed "s/./& /g")
  title_spaced=$(echo "$title " | sed "s/./& /g")
  echo "╔════════╗ ║  ${artist_spaced}  -  ${title_spaced}  ║ ╚════════╝"
else
  echo "Nothing Playing"
fi
