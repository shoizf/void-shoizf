#!/usr/bin/env bash
# install.sh — Master Orchestrator (Root-Driven Mode)
# MUST be run as root. Guaranteed zero-interruption execution.

set -euo pipefail

# --- 1. ROOT VALIDATION (The "No Interruption" Guarantee) ---
if [ "$EUID" -ne 0 ]; then
  echo "❌ ERROR: This script must be run as ROOT."
  echo "👉 Usage: sudo ./install.sh"
  exit 1
fi

# --- 2. TARGET USER DETECTION ---
if [ -n "${SUDO_USER:-}" ]; then
  TARGET_USER="$SUDO_USER"
else
  echo "⚠️  Running directly as root (not via sudo)."
  read -p "Enter the target username to install for: " TARGET_USER
fi

if ! id "$TARGET_USER" &>/dev/null; then
  echo "❌ User '$TARGET_USER' does not exist."
  exit 1
fi

# Get User Home & Group
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_GROUP=$(id -gn "$TARGET_USER")

echo "🚀 Initializing Installation for User: $TARGET_USER ($TARGET_HOME)"

# --- 3. LOGGING SETUP ---
LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="void-shoizf-root"
MASTER_LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"

# Create file & fix ownership immediately so User can tail it
touch "$MASTER_LOG_FILE"
chown "$TARGET_USER:$TARGET_GROUP" "$LOG_DIR" "$MASTER_LOG_FILE"

# Export variables so child scripts inherit them
export VOID_SHOIZF_MASTER_LOG="$MASTER_LOG_FILE"
export TARGET_USER
export TARGET_HOME

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [MASTER] $*"
  echo "$msg" | tee -a "$MASTER_LOG_FILE"
  # Keep permissions correct after root writes to it
  chown "$TARGET_USER:$TARGET_GROUP" "$MASTER_LOG_FILE"
}

log "▶ Starting Root-Driven Install for $TARGET_USER"

# --- 4. PATHS & CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
INSTALLERS_DIR="$SCRIPT_DIR/installers"

# VM Detection
IS_VM=false
if [ -f "$UTILS_DIR/is_vm.sh" ]; then
  source "$UTILS_DIR/is_vm.sh"
  : "${IS_VM:=false}"
  log "INFO VM detection: IS_VM=${IS_VM}"
fi

# --- 5. CORE SYSTEM SERVICES (Tier 0) ---
# We enable fundamental services here to ensure packages/sddm don't fail.
log "Configuring Core Services..."

SV_DIR="/etc/sv"
RUNIT_DIR="/etc/runit/runsvdir/default"

# DBUS ACTIVATION (Critical for SDDM & NetworkManager)
if [ -d "$SV_DIR/dbus" ]; then
  if [ ! -L "$RUNIT_DIR/dbus" ]; then
    ln -s "$SV_DIR/dbus" "$RUNIT_DIR/dbus"
    log "OK Enabled Core Service: dbus"
  else
    log "INFO Core Service dbus already active"
  fi
else
  log "WARN dbus service not found (packages.sh will likely install it next)"
fi

# --- 6. INSTALLER DEFINITIONS ---

ROOT_SCRIPTS=(
  "packages"       # Installs xbps packages, setup repos
  "hyprlock"       # Configures sudoers (Must be Root)
  "sddm_astronaut" # /usr/share/sddm modifications
  "intel"          # Kernel modules
  "vulkan-intel"   # Drivers
  "nvidia"         # Drivers
  "networkman"     # System services
  "grub"           # /boot config
)

USER_SCRIPTS=(
  "fonts"             # ~/.local/share/fonts
  "audio-integration" # Pipewire config
  "awww"              # Wallpaper daemon build
  "dev-tools"         # Neovim/Tmux
  "niri"              # Window Manager config
  "waybar"            # Status Bar config
  "mako"              # Notification config
)

# EXECUTION ORDER (Logical Flow)
EXECUTION_ORDER=(
  "packages" # 1. Get software & repos (ROOT)
  "fonts"    # 2. Assets (USER)
  "audio-integration"
  "awww" # 4. Build wallpaper tools (USER)
  "dev-tools"
  "niri"
  "waybar"
  "hyprlock" # 8. Security & Sleep (ROOT)
  "mako"
  "sddm_astronaut" # 10. Login Manager (ROOT)
  "intel"
  "vulkan-intel"
  "nvidia"
  "networkman" # 14. Networking (ROOT)
  "grub"       # 15. Bootloader (ROOT)
)

# --- 7. EXECUTION ENGINE ---

for script_name in "${EXECUTION_ORDER[@]}"; do
  SCRIPT_PATH="$INSTALLERS_DIR/${script_name}.sh"

  if [ ! -f "$SCRIPT_PATH" ]; then
    log "WARN Missing installer: $SCRIPT_PATH — skipping."
    continue
  fi

  # VM Skip Logic
  if [[ "$IS_VM" == true && "$script_name" =~ ^(intel|vulkan-intel|nvidia|networkman)$ ]]; then
    log "SKIP ${script_name}.sh — skipped for VM environment."
    continue
  fi

  # Determine Mode
  MODE="USER"
  for r in "${ROOT_SCRIPTS[@]}"; do
    if [[ "$r" == "$script_name" ]]; then
      MODE="ROOT"
      break
    fi
  done

  log "▶ Executing ${script_name}.sh [Mode: $MODE]"

  if [[ "$MODE" == "ROOT" ]]; then
    # RUN AS ROOT
    # We preserve env vars so child scripts see MASTER_LOG and TARGET_USER
    if bash "$SCRIPT_PATH"; then
      log "OK ${script_name}.sh success"
    else
      log "ERROR ${script_name}.sh failed (Root mode)"
      # Optional: exit 1 here if you want to stop on error
    fi
  else
    # RUN AS USER (Drop Privileges)
    # sudo -u preserves the environment variables we exported
    if sudo -u "$TARGET_USER" VOID_SHOIZF_MASTER_LOG="$VOID_SHOIZF_MASTER_LOG" bash "$SCRIPT_PATH"; then
      log "OK ${script_name}.sh success"
    else
      log "ERROR ${script_name}.sh failed (User mode)"
    fi
  fi
done

# Final Cleanup
chown -R "$TARGET_USER:$TARGET_GROUP" "$LOG_DIR"
log "✅ Installation Sequence Complete."
