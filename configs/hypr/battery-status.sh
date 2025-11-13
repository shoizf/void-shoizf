#!/usr/bin/env bash
# battery-status.sh
# =============================================================================
# Battery status for hyprlock
# Adapted from Kaushallrai's hyprlock: https://github.com/Kaushallrai/hyprlock.git
# =============================================================================

set -euo pipefail

CAPACITY_FILE=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || true)
if [[ -z "$CAPACITY_FILE" ]]; then
  echo ""
  exit 0
fi

STATUS_FILE="${CAPACITY_FILE%/*}/status"
CAPACITY=$(cat "$CAPACITY_FILE" 2>/dev/null || echo 0)
STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "")

ICON="󰂎"
if [[ "$STATUS" == "Charging" ]]; then
  ICON="󰂄"
elif ((CAPACITY >= 95)); then
  ICON="󰁹"
elif ((CAPACITY >= 70)); then
  ICON="󰂀"
elif ((CAPACITY >= 40)); then
  ICON="󰁾"
elif ((CAPACITY >= 10)); then
  ICON="󰁼"
fi

echo "$ICON ${CAPACITY}%"
