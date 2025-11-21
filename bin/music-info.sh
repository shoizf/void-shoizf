#!/usr/bin/env bash
# music-info.sh
# =============================================================================
# Show current playing track (Artist - Title)
# Adapted for void-shoizf from Kaushallrai's hyprlock: https://github.com/Kaushallrai/hyprlock.git
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

artist=$(playerctl -p "$player" metadata artist 2>/dev/null || echo "")
title=$(playerctl -p "$player" metadata title 2>/dev/null || echo "")

if [[ -z "$artist" && -z "$title" ]]; then
  echo ""
  exit 0
fi

artist="${artist:0:30}"
title="${title:0:45}"

echo "$artist - $title"
