#!/usr/bin/env bash
# installers/packages.sh — core system packages for void-shoizf
# HYBRID SCRIPT (runs as user, uses sudo for installation)

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
    TARGET_HOME="${TARGET_HOME:-$HOME}"
    LOG_DIR="$TARGET_HOME/.local/state/void-shoizf/log"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

QUIET_MODE=${QUIET_MODE:-true}

# ------------------------------------------------------
# 2. SAFE LOGGING (FIXED FOR set -e)
# ------------------------------------------------------
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
    echo "$msg" >>"$LOG_FILE"

    # DO NOT USE: [ "$QUIET_MODE" = false ] && echo "$msg"
    # set -e kills the script because the test returns 1
    if [ "$QUIET_MODE" = "false" ]; then
        echo "$msg"
    fi
}

info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok()    { log "OK    $*"; }
pp()    { echo -e "$*"; }

# ------------------------------------------------------
# 3. HEADER
# ------------------------------------------------------
pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"
info "Installing verified core packages"

# ------------------------------------------------------
# 4. VALIDATION
# ------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    warn "Running as root — should be hybrid USER mode"
fi

# ------------------------------------------------------
# 5. ENABLE REPOS (REQUIRED)
# ------------------------------------------------------
info "Enabling official repos (nonfree + multilib)..."

if sudo xbps-install -y void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree; then
    ok "Repos enabled"
    sudo xbps-install -Sy
else
    error "Failed to enable repos"
    exit 1
fi

# ------------------------------------------------------
# 6. PACKAGE LIST (VERIFIED)
# ------------------------------------------------------
PACKAGES=(
  base-devel curl git wget unzip tree lsd ripgrep fd jq psmisc dateutils
  lm_sensors acpi power-profiles-daemon upower

  xorg-minimal xf86-input-libinput xf86-video-intel
  mesa-dri intel-media-driver libva-utils mesa-vaapi mesa-demos

  pipewire wireplumber wireplumber-elogind
  alsa-pipewire libspa-alsa alsa-utils alsa-firmware sof-firmware rtkit

  NetworkManager networkmanager-dmenu nm-tray network-manager-applet

  niri xdg-utils wayland
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr
  xwayland-satellite polkit-kde-agent sddm elogind dbus-libs dbus-x11

  nvidia nvidia-dkms nvidia-firmware nvidia-libs nvidia-gtklibs
  nvidia-vaapi-driver dkms libglvnd vulkan-loader nvidia-libs-32bit

  mesa-vulkan-intel mesa-vulkan-lavapipe
  Vulkan-Tools Vulkan-ValidationLayers Vulkan-Headers

  kitty firefox dolphin Waybar walker mako pavucontrol wob swayimg qalculate-qt

  neovim tmux wl-clipboard mpc playerctl mpv scdoc

  cargo nodejs gtk+3 liblz4-devel desktop-file-utils
  cups cups-filters gammastep brightnessctl wlr-randr
)

# ------------------------------------------------------
# 7. INSTALLATION
# ------------------------------------------------------
info "Installing ${#PACKAGES[@]} packages..."

if sudo xbps-install -Sy "${PACKAGES[@]}"; then
    ok "All packages installed successfully"
else
    error "One or more packages failed"
    exit 1
fi

# ------------------------------------------------------
# 8. END
# ------------------------------------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
