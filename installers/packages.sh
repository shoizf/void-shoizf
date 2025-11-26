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
  # --- 1. BASE SYSTEM & BUILD TOOLS ---
  base-devel
  curl git wget unzip tree

  # --- 2. HARDWARE DRIVERS & BACKEND ---
  # Xorg Minimal is required for SDDM login screen input
  xorg-minimal xf86-input-libinput xf86-video-intel mesa-dri

  # Audio Backend (The Full Stack)
  # Included BOTH wireplumber (Core) and wireplumber-elogind (Integration)
  pipewire wireplumber wireplumber-elogind
  pipewire-pulse alsa-pipewire libspa-alsa
  alsa-utils alsa-firmware sof-firmware rtkit

  # Power & Bluetooth
  power-profiles-daemon acpi lm_sensors

  # --- 3. DESKTOP ENVIRONMENT (Niri) ---
  niri xdg-utils xdg-desktop-portal-wlr xdg-desktop-portal-gtk wayland
  xwayland-satellite polkit-kde-agent
  sddm elogind dbus-libs dbus-x11

  # --- 4. GUI APPLICATIONS ---
  kitty        # Terminal
  firefox      # Browser
  dolphin      # File Manager
  waybar       # Status Bar
  walker       # App Launcher
  mako         # Notifications
  pavucontrol  # Volume Control
  wob          # Volume/Brightness Overlay
  swayimg      # Image Viewer
  qalculate-qt # Calculator

  # --- 5. CLI UTILITIES & TOOLS ---
  neovim        # Editor
  tmux          # Terminal Multiplexer
  lsd           # Modern 'ls'
  ripgrep fd jq # Search & JSON tools
  psmisc        # 'killall' etc
  wl-clipboard  # Clipboard manager
  mpc playerctl # Media control
  mpv           # Video player
  scdoc         # Man page generator

  # --- 6. LIBS & DEPS ---
  cargo        # Rust package manager
  nodejs       # JS Runtime
  gtk+3        # GTK3 libs
  liblz4-devel # Compression lib
  desktop-file-utils
  cups cups-filters # Printing
  gammastep brightnessctl dateutils wlr-randr
)

# --- 4. INSTALL ---
log "Installing ${#PACKAGES[@]} core packages..."
sudo xbps-install -Sy --yes "${PACKAGES[@]}"

log "✅ packages.sh finished"
