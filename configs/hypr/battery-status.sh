#!/usr/bin/env bash
# =============================================================================
# battery-status.sh — Displays battery icon and percentage
#
# 🔋 Uses globbing for BAT* devices
# 🧠 Credits:
#   - Based on EnviiLock logic by Kaushallrai
#   - Fixed for void-shoizf (desktop-safe, no hardcoded paths)
# =============================================================================

set -euo pipefail

STATUS_FILE=$(ls /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1)
CAPACITY_FILE=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1)

# No battery detected (desktop)
if [[ -z "$CAPACITY_FILE" ]]; then
  echo ""
  exit 0
fi

STATUS=$(cat "$STATUS_FILE" 2>/dev/null)
CAPACITY=$(cat "$CAPACITY_FILE" 2>/dev/null)

# Choose icon based on charge state and level
if [[ "$STATUS" == "Charging" ]]; then
  ICON="󰂄" # Charging
else
  if ((CAPACITY >= 95)); then
    ICON="󰁹"
  elif ((CAPACITY >= 70)); then
    ICON="󰂀"
  elif ((CAPACITY >= 40)); then
    ICON="󰁾"
  elif ((CAPACITY >= 10)); then
    ICON="󰁼"
  else
    ICON="󰂎"
  fi
fi

echo "$ICON  ${CAPACITY}%"
