#!/usr/bin/env bash
# installers/install-packages.sh — core system packages (must run as root)

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "ERROR install-packages.sh must be run as root (via sudo)."
  exit 1
fi

LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
MASTER_LOG="$LOG_DIR/master-install.log"

echo "[${SCRIPT_NAME}] Starting package install" | tee -a "$LOG_FILE" >>"$MASTER_LOG"

PACKAGES=(
  niri xdg-utils xdg-desktop-portal-wlr wayland
  xwayland-satellite polkit-kde-agent swaybg alacritty zsh walker waybar wob mpc yazi
  pcmanfm pavucontrol swayimg cargo gammastep brightnessctl xdg-desktop-portal-gtk
  power-profiles-daemon firefox sddm tmux ripgrep fd tree dbus-libs dbus-x11 cups cups-filters acpi jq dateutils
  wlr-randr procps-ng playerctl lsd unzip flatpak elogind nodejs mako wget scdoc liblz4-devel dolphin qalculate-qt curl git desktop-file-utils gtk+3 lm_sensors neovim
)

echo "Installing ${#PACKAGES[@]} packages..."
xbps-install -Sy --yes "${PACKAGES[@]}"

echo "Package install completed" | tee -a "$LOG_FILE" >>"$MASTER_LOG"
