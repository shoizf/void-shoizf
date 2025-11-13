#!/bin/bash
# ===============================================================
#  wallpaper-cycler.sh — Dynamic Wallpaper Manager (Simple CLI)
# ===============================================================
# Usage:
#   wallpaper-cycler.sh [option]
#
# Options:
#   --next, -n           Cycle to the next wallpaper in the list.
#   --previous, -p       Go back to the previous wallpaper.
#   --item <index>, -i <index>  Set wallpaper by number (1–10).
#   --help, -h           Show this help message.
#
# Notes:
#   • Default (no args) starts the auto-cycling loop (every 30 mins).
#   • Wallpapers are stored in ~/.local/share/wallpapers
#   • Source: https://github.com/D3Ext/aesthetic-wallpapers/images
#   • Requires: jq, wget, awww
# ===============================================================

set -euo pipefail

# --- CONFIG ---
WALLPAPER_DIR="$HOME/.local/share/wallpapers"
INDEX_FILE="$WALLPAPER_DIR/.current_index"
SLEEP_DURATION=1800
API_URL="https://api.github.com/repos/D3Ext/aesthetic-wallpapers/contents/images"
USER_AGENT="wallpaper-cycler/1.0 (+https://github.com/yourrepo)"
JSON_FILE="$WALLPAPER_DIR/github-api.json"
MAX_WALLS=10

mkdir -p "$WALLPAPER_DIR"

# --- FUNCTIONS ---

download_wallpapers() {
  echo "📥 Checking wallpaper cache..."
  if [ "$(ls -1 "$WALLPAPER_DIR"/*.jpg 2>/dev/null | wc -l)" -lt "$MAX_WALLS" ]; then
    echo "Downloading initial set of $MAX_WALLS wallpapers..."
    wget -q -U "$USER_AGENT" -O "$JSON_FILE" "$API_URL" || {
      echo "⚠️  Failed to download image list from GitHub."
      return
    }

    IMAGE_URLS=$(jq -r '.[] | select(.type=="file") | .download_url | select(. | endswith(".jpg") or endswith(".png"))' "$JSON_FILE" | shuf -n "$MAX_WALLS")

    i=1
    for url in $IMAGE_URLS; do
      echo "Downloading wallpaper $i..."
      wget -q -U "$USER_AGENT" -O "$WALLPAPER_DIR/wallpaper-$i.jpg" "$url" || echo "⚠️ Failed to download wallpaper $i"
      ((i++))
    done
    echo "✅ Download complete."
  else
    echo "✅ Wallpaper cache already populated."
  fi
}

set_wallpaper() {
  local index="$1"
  local file="$WALLPAPER_DIR/wallpaper-$index.jpg"

  if [ ! -f "$file" ]; then
    echo "❌ Wallpaper $index not found."
    exit 1
  fi

  echo "🖼️  Setting wallpaper #$index → $(basename "$file")"
  awww img "$file" --transition-type random
  echo "$index" >"$INDEX_FILE"
}

get_current_index() {
  if [ -f "$INDEX_FILE" ]; then
    cat "$INDEX_FILE"
  else
    echo 1
  fi
}

cycle_next() {
  local current
  current=$(get_current_index)
  local next=$((current + 1))
  if [ "$next" -gt "$MAX_WALLS" ]; then next=1; fi
  set_wallpaper "$next"
}

cycle_previous() {
  local current
  current=$(get_current_index)
  local prev=$((current - 1))
  if [ "$prev" -lt 1 ]; then prev="$MAX_WALLS"; fi
  set_wallpaper "$prev"
}

auto_cycle_loop() {
  echo "🔁 Starting wallpaper auto-cycle loop..."
  while true; do
    cycle_next
    echo "💤 Sleeping for $SLEEP_DURATION seconds..."
    sleep "$SLEEP_DURATION"
  done
}

# --- MAIN ---

download_wallpapers

case "${1:-}" in
--next | -n)
  cycle_next
  ;;
--previous | -p)
  cycle_previous
  ;;
--item | -i)
  if [[ -z "${2:-}" || ! "${2:-}" =~ ^[0-9]+$ || "${2:-}" -lt 1 || "${2:-}" -gt "$MAX_WALLS" ]]; then
    echo "Usage: $0 --item <1-$MAX_WALLS>"
    exit 1
  fi
  set_wallpaper "$2"
  ;;
--help | -h)
  grep '^#' "$0" | head -n 25 | sed 's/^# \{0,1\}//'
  ;;
"")
  auto_cycle_loop
  ;;
*)
  echo "Unknown option: $1"
  echo "Use --help for usage information."
  exit 1
  ;;
esac
