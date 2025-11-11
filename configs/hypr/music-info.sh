#!/usr/bin/env bash
# =============================================================================
# music-info.sh — Displays current playing track (Artist - Title)
#
# 🎵 Compatible with playerctl (MPRIS)
# 🧠 Credits:
#   - Original logic from Kaushallrai’s EnviiLock (Hyprlock theme)
#   - Modified for 'void-shoizf' — flexible player detection
# =============================================================================

set -euo pipefail

# Get the first (oldest) available MPRIS player
player=$(playerctl -l 2>/dev/null | head -n 1)

# If no player found
if [[ -z "$player" ]]; then
  echo "No Player Active"
  exit 0
fi

status=$(playerctl -p "$player" status 2>/dev/null || echo "Stopped")

if [[ "$status" != "Playing" ]]; then
  echo "Paused"
  exit 0
fi

artist=$(playerctl -p "$player" metadata artist 2>/dev/null || echo "Unknown Artist")
title=$(playerctl -p "$player" metadata title 2>/dev/null || echo "Unknown Title")

# Trim long strings
artist="${artist:0:30}"
title="${title:0:45}"

echo "$artist - $title"
