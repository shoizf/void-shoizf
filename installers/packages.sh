#!/usr/bin/env bash
# installers/packages.sh — core system packages for void-shoizf
# USER-SCRIPT (non-root; uses sudo internally)

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"


if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  MASTER_MODE=true
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  MASTER_MODE=false
  HOME="${HOME:-$TARGET_HOME}"
  LOG_DIR="$HOME/.local/state/void-shoizf/log"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

QUIET_MODE=${QUIET_MODE:-true}

# ------------------------------------------------------
# 2. LOGGING FUNCTIONS
# ------------------------------------------------------

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >>"$LOG_FILE"
  [ "$QUIET_MODE" = false ] && echo "$msg"
}

info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok() { log "OK    $*"; }
pp() { echo -e "$*"; }

# ------------------------------------------------------
# 3. STARTUP HEADER
# ------------------------------------------------------

pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"
info "Installing core packages into system"

# ------------------------------------------------------
# 4. VALIDATION
# ------------------------------------------------------

if [ "$EUID" -eq 0 ]; then
  warn "Running as root — packages.sh is intended for user execution"
fi

# ------------------------------------------------------
# 5. CORE LOGIC
# ------------------------------------------------------

# --- 5.1 Hyprland Repo Setup ---
HYPR_REPO_CONF="/etc/xbps.d/hyprland-void.conf"
HYPR_REPO_URL="repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc"

if [ ! -f "$HYPR_REPO_CONF" ]; then
  info "Adding Hyprland (Makrennel) repo → $HYPR_REPO_CONF"
  echo "$HYPR_REPO_URL" | sudo tee "$HYPR_REPO_CONF" >/dev/null
  ok "Hyprland repo added"
else
  info "Hyprland repo already exists"
fi

# --- 5.2 Force install Hyprlock and Hypridle ---
info "Installing Hyprlock and Hypridle..."
if sudo xbps-install -yN hyprlock hypridle; then
  ok "Hyprlock/Hypridle installed"
else
  error "Failed to install Hyprlock/Hypridle — check repo or network"
fi

# ------------------------------------------------------
# 5.3 PACKAGES — MASTER PACKAGE LIST
# ------------------------------------------------------

PACKAGES=(

  # --------------------------------------------------
  # --- Base System & Tools ---
  # --------------------------------------------------
  base-devel curl git wget unzip tree lsd ripgrep fd jq psmisc dateutils

  # --------------------------------------------------
  # --- Hardware / CPU / Sensors ---
  # --------------------------------------------------
  lm_sensors acpi power-profiles-daemon upower

  # --------------------------------------------------
  # --- Xorg / Input Drivers / Intel GPU ---
  # --------------------------------------------------
  xorg-minimal xf86-input-libinput xf86-video-intel
  mesa-dri mesa-dri-32bit
  intel-media-driver libva-utils
  mesa-vaapi mesa-vaapi-32bit
  mesa-demos

  # --------------------------------------------------
  # --- Audio (PipeWire + ALSA) ---
  # --------------------------------------------------
  pipewire wireplumber wireplumber-elogind
  pipewire-pulse alsa-pipewire libspa-alsa
  alsa-utils alsa-firmware sof-firmware
  rtkit

  # --------------------------------------------------
  # --- Networking ---
  # --------------------------------------------------
  NetworkManager networkmanager-dmenu nm-tray network-manager-applet

  # --------------------------------------------------
  # --- Desktop Environment (Niri / Wayland) ---
  # --------------------------------------------------
  niri xdg-utils wayland
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr
  xwayland-satellite polkit-kde-agent
  sddm elogind dbus-libs dbus-x11

  # --------------------------------------------------
  # --- NVIDIA PRIME OFFLOAD (Hybrid: Intel primary + NVIDIA secondary) ---
  # --------------------------------------------------
  nvidia nvidia-dkms nvidia-firmware nvidia-libs nvidia-gtklibs
  nvidia-vaapi-driver dkms libglvnd vulkan-loader

  # 32-bit NVIDIA
  nvidia-libs-32bit

  # --------------------------------------------------
  # --- Vulkan (Intel + Software + Tools) ---
  # --------------------------------------------------
  mesa-vulkan-intel mesa-vulkan-intel-32bit
  mesa-vulkan-lavapipe mesa-vulkan-lavapipe-32bit
  vulkan-loader vulkan-loader-32bit
  vulkan-tools vulkan-validationlayers vulkan-headers

  # --------------------------------------------------
  # --- GUI Apps ---
  # --------------------------------------------------
  kitty firefox dolphin waybar walker mako pavucontrol
  wob swayimg qalculate-qt

  # --------------------------------------------------
  # --- CLI Tools / Utilities ---
  # --------------------------------------------------
  neovim tmux wl-clipboard mpc playerctl mpv scdoc

  # --------------------------------------------------
  # --- Dev Dependencies ---
  # --------------------------------------------------
  cargo nodejs gtk+3 liblz4-devel desktop-file-utils
  cups cups-filters gammastep brightnessctl wlr-randr
)

# ------------------------------------------------------
# 5.4 INSTALL ALL PACKAGES
# ------------------------------------------------------

info "Installing ${#PACKAGES[@]} core packages..."
if sudo xbps-install -yN "${PACKAGES[@]}"; then
  ok "All packages installed successfully"
else
  warn "One or more packages failed to install — check logs"
fi

# ------------------------------------------------------
# 6. END
# ------------------------------------------------------

log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
