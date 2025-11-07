#!/bin/bash
#
# DYNAMIC WALLPAPER CYCLER (FINAL "GitHub API" VERSION)
#
# This "capable" script:
# 1. Uses the GitHub API to list files in a repo.
# 2. Downloads ONE JSON file.
# 3. Filters for .jpg/.png files.
# 4. Picks one at random and sets it.
# 5. Is "offline-first."
#
# Credits:
# - Original "aesthetic-wallpapers" repo: D3Ext
# - Original "Awesome_Wallpapers" web app: AlexandrosLiaskos
#
# REQUIRES: 'jq', 'wget', 'awww-daemon' (must be running)
#

# --- CONFIGURATION ---
WALLPAPER_FILE="$HOME/.config/wallpapers/current-wallpaper.jpg"
SLEEP_DURATION=1800 # 30 minutes

API_URL="https://api.github.com/repos/D3Ext/aesthetic-wallpapers/contents/images"
JSON_FILE="$HOME/.config/wallpapers/github-api.json"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0"
# --- END CONFIGURATION ---

mkdir -p "$HOME/.config/wallpapers"

# --- "Offline-First" - Set wallpaper immediately ---
if [ -f "$WALLPAPER_FILE" ]; then
  echo "Wallpaper Cycler: Setting last-used wallpaper immediately."
  awww img "$WALLPAPER_FILE"
else
  echo "Wallpaper Cycler: No cached wallpaper found. Waiting for first download..."
fi
# --- END ---

# --- MAIN LOOP ---
while true; do
  echo "Wallpaper Cycler: Checking for internet..."

  if ping -c 1 -W 1 8.8.8.8 2% >/dev/null >&1; then
    echo "Wallpaper Cycler: Internet found. Checking for new list..."

    if [ ! -s "$JSON_FILE" ] || [ -n "$(find "$JSON_FILE" -mtime +1 2>/dev/null)" ]; then
      echo "Wallpaper Cycler: Downloading new wallpaper list from GitHub API..."
      wget -q -U "$USER_AGENT" -O "$JSON_FILE" "$API_URL"
      if [ $? -ne 0 ]; then
        echo "Wallpaper Cycler: FAILED to download JSON list."
      fi
    else
      echo "Wallpaper Cycler: Wallpaper list is up-to-date."
    fi

    if [ -s "$JSON_FILE" ]; then
      IMAGE_URL=$(cat "$JSON_FILE" | jq -r '.[] | select(.type == "file") | .download_url | select(. | endswith(".jpg") or endswith(".png"))' | shuf -n 1)

      if [ -z "$IMAGE_URL" ]; then
        echo "Wallpaper Cycler: FAILED to find any image URLs in the JSON."
        sleep 60
        continue
      fi

      wget -q -U "$USER_AGENT" -O "$WALLPAPER_FILE" "$IMAGE_URL"

      if [ $? -eq 0 ] && [ -s "$WALLPAPER_FILE" ]; then
        echo "Wallpaper Cycler: Download successful. Setting new wallpaper."
        awww img "$WALLPAPER_FILE" --transition-type random
      else
        echo "Wallpaper Cycler: Download failed. Retrying in 60s."
        sleep 60
        continue
      fi
    else
      echo "Wallpaper Cycler: JSON file is empty. Cannot select wallpaper."
    fi
  else
    echo "Wallpaper Cycler: No internet. Will try again in 30 minutes."
  fi

  echo "Wallpaper Cycler: Sleeping for $SLEEP_DURATION seconds..."
  sleep $SLEEP_DURATION
done
