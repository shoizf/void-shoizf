#!/usr/bin/env bash
# installers/packages.sh — core system packages
# Run as USER. Invokes sudo internally.

set -euo pipefail

# --- Logging setup ---
LOG_DIR="$HOME/.local/state/void-shoizf/log"
mkdir -p "$LOG_DIR"
SCRIPT_NAME="$(basename "$0" .sh)"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

log "▶ packages.sh starting"

# --- 1. REPO SETUP ---
HYPR_REPO_CONF="/etc/xbps.d/hyprland-void.conf"
HYPR_REPO_URL="repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc"

if [ ! -f "$HYPR_REPO_CONF" ]; then
  log "Adding Makrennel repo..."
  echo "$HYPR_REPO_URL" | sudo tee "$HYPR_REPO_CONF" >/dev/null
else
  log "Makrennel repo config exists."
fi

# --- 2. FORCE INSTALL HYPR TOOLS ---
log "Syncing repo and installing Hyprland utils..."
if sudo xbps-install -Sy hyprlock hypridle; then
  log "✅ Hyprlock/Hypridle installed."
else
  log "ERROR Failed to install Hyprlock/Hypridle. Check repo/network."
fi

# --- 3. CORE PACKAGES ---
PACKAGES=(
  # Build Tools
  base-devel

  # Xorg Drivers (Required for SDDM Input)
  xorg-minimal xf86-input-libinput xf86-video-intel mesa-dri

  # Desktop Environment
  # Removed: swaybg (replaced by awww), alacritty (replaced by kitty)
  niri xdg-utils xdg-desktop-portal-wlr wayland
  xwayland-satellite polkit-kde-agent kitty zsh walker Waybar wob mpc yazi

  # Audio & Media
  pavucontrol playerctl mpv pipewire wireplumber pipewire-pulse alsa-utils libspa-alsa sof-firmware

  # System Utilities
  qalculate-qt dolphin lsd swayimg cargo gammastep brightnessctl xdg-desktop-portal-gtk
  power-profiles-daemon firefox sddm tmux ripgrep fd tree dbus-libs dbus-x11 cups cups-filters acpi jq dateutils
  wlr-randr procps-ng unzip flatpak elogind nodejs mako wget scdoc liblz4-devel curl git desktop-file-utils gtk+3 lm_sensors neovim
)

# --- 4. INSTALL ---
log "Installing ${#PACKAGES[@]} core packages..."
sudo xbps-install -Sy --yes "${PACKAGES[@]}"

log "✅ packages.sh finished"
