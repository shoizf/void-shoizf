#!/usr/bin/env bash
# installers/install-packages.sh
#
# This script is called by the main install.sh and *must be run as root*
# (or via sudo) as it installs system-wide packages.

set -euo pipefail

echo "--- [Core Packages Installer] ---"

# Use the reliable array format
PACKAGES_ARRAY=(
  "xbps" "niri" "xdg-desktop-portal-wlr" "wayland" "xwayland-satellite"
  "polkit-kde-agent" "swaybg" "alacritty" "zsh" "walker" "Waybar" "wob"
  "mpc" "yazi" "pcmanfm" "pavucontrol" "swayimg" "cargo" "gammastep"
  "brightnessctl" "xdg-desktop-portal" "xdg-desktop-portal-gtk"
  "power-profiles-daemon" "firefox" "sddm" "tmux" "ripgrep" "fd" "tree"
  "xorg-server" "xf86-input-libinput" "dbus-libs" "dbus-x11" "cups"
  "cups-filters" "acpi" "jq" "dateutils" "wlr-randr" "procps-ng"
  "playerctl" "lsd" "unzip" "flatpak" "elogind" "nodejs" "mako" "lm_sensors"
  "wget" "scdoc" "liblz4-devel"
)

echo "📦 Installing core packages..."
echo "DEBUG: Package list to install:"
printf "[%s]\n" "${PACKAGES_ARRAY[@]}"

# 'sudo' is omitted here because the parent install.sh
# is responsible for calling this script with sudo.
xbps-install -Sy "${PACKAGES_ARRAY[@]}"

echo "✅ Core packages installed successfully!"
