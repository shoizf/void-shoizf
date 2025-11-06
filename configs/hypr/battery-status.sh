#!/bin/bash
#
# battery-status.sh (FIXED)
#
# This "capable" script:
# - Uses the "EnviiLock" globbing method (BAT*)
#   which is proven to work.
#

# Use the shell's globbing to find the files, and 'head -n 1'
# to get the first battery.
STATUS_FILE=$(ls /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1)
CAPACITY_FILE=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1)

# If no battery file is found, we're on a desktop. Print nothing.
if [ -z "$CAPACITY_FILE" ]; then
  echo ""
  exit 0
fi

# Now we can safely cat the files
STATUS=$(cat "$STATUS_FILE" 2>/dev/null)
CAPACITY=$(cat "$CAPACITY_FILE" 2>/dev/null)

if [ "$STATUS" = "Charging" ]; then
  ICON="󰂄" # Charging icon
else
  # Not charging, pick icon based on capacity
  if [ "$CAPACITY" -ge 95 ]; then
    ICON="󰁹" # Full
  elif [ "$CAPACITY" -ge 70 ]; then
    ICON="󰂀" # 3/4
  elif [ "$CAPACITY" -ge 40 ]; then
    ICON="󰁾" # 1/2
  elif [ "$CAPS_FILE" -ge 10 ]; then
    ICON="󰁼" # 1/4
  else
    ICON="󰂎" # Empty
  fi
fi

# Print the final icon and percentage
echo "$ICON  $CAPACITY%"
