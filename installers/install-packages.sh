#!/usr/bin/env bash
# installers/install-packages.sh — core system packages (must run as root)

set -euo pipefail

# --- Logging setup ---
# Find the user's home dir for logging, even when run as root
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_HOME="$HOME"
fi

LOG_DIR="$USER_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
SCRIPT_NAME="$(basename "$0" .sh)"

# Check if we're being run by the master installer
if [ -n "$VOID_SHOIZF_MASTER_LOG" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  # We are being run directly, create our own log
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}
# --- End Logging setup ---

if [ "$EUID" -ne 0 ]; then
  log "ERROR install-packages.sh must be run as root (via sudo)."
  exit 1
fi

log "[${SCRIPT_NAME}] Starting package install"

PACKAGES=(
  niri xdg-utils xdg-desktop-portal-wlr wayland
  xwayland-satellite polkit-kde-agent swaybg alacritty zsh walker waybar wob mpc yazi
  pcmanfm pavucontrol swayimg cargo gammastep brightnessctl xdg-desktop-portal-gtk
  power-profiles-daemon firefox sddm tmux ripgrep fd tree dbus-libs dbus-x11 cups cups-filters acpi jq dateutils
  wlr-randr procps-ng playerctl lsd unzip flatpak elogind nodejs mako wget scdoc liblz4-devel dolphin qalculate-qt curl git desktop-file-utils gtk+3 lm_sensors neovim
)

log "Installing ${#PACKAGES[@]} packages..."
xbps-install -Sy --yes "${PACKAGES[@]}"

log "Package install completed"
