#!/usr/bin/env bash
###############################################################################
# install.sh — Main installer for void-shoizf
# Author: shoizf
#
# Safe, idempotent installation script for Void Linux customization.
# Handles sudo configuration, installer submodules, and clean restoration.
# Run as a normal user (not root).
###############################################################################

set -euo pipefail

###############################################################################
# 0. Initialization
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date '+%Y%m%d_%H%M%S').log"

if ! touch "$LOG_FILE" 2>/dev/null; then
  echo "❌ Cannot create log file at $LOG_FILE"
  exit 1
fi

set +o pipefail
exec > >(tee -a "$LOG_FILE") 2>&1
set -o pipefail

echo "📜 Logging to: $LOG_FILE"
echo "------------------------------------------------------------"
echo "Started at: $(date)"
echo "User: $(whoami)"
echo "Working directory: $(pwd)"
echo "------------------------------------------------------------"

PS4='+ [$(date "+%H:%M:%S")] '
set -x

###############################################################################
# 1. Sanity Checks
###############################################################################
if [[ "$(id -u)" -eq 0 ]]; then
  echo "❌ Do NOT run this as root."
  exit 1
fi

TARGET_USER=$(whoami)
TARGET_USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if [[ -z "$TARGET_USER" || -z "$TARGET_USER_HOME" ]]; then
  echo "❌ Could not determine target user or home directory."
  exit 1
fi

echo "Running installation for user: $TARGET_USER ($TARGET_USER_HOME)"

###############################################################################
# 2. Temporary NOPASSWD sudo setup (self-healing)
###############################################################################
USER_NAME="$TARGET_USER"
SUDOERS_D_FRAGMENT="/etc/sudoers.d/99-shoizf-temp"

echo "🧩 Checking for leftover sudo configuration..."
if sudo test -f "$SUDOERS_D_FRAGMENT"; then
  echo "⚠️ Found leftover sudoers fragment. Removing..."
  sudo rm -f "$SUDOERS_D_FRAGMENT"
  echo "✅ Removed old fragment."
fi

OLD_BACKUPS=$(sudo find /etc -maxdepth 1 -type f -name "sudoers.shoizf.backup.*" -print -delete 2>/dev/null || true)
if [[ -n "$OLD_BACKUPS" ]]; then
  echo "🧾 Removed stale sudoers backups:"
  echo "$OLD_BACKUPS"
fi

sudo visudo -c >/dev/null 2>&1 && echo "✅ Sudoers syntax clean before modification."

_cleanup_sudoers_fragment() {
  rc=$?
  echo "♻️ Cleaning sudoers temp fragment (exit: $rc)..."
  sudo rm -f "$SUDOERS_D_FRAGMENT" 2>/dev/null || true
  sudo visudo -c >/dev/null 2>&1 && echo "✅ Verified sudoers syntax post-cleanup."
  return $rc
}
trap _cleanup_sudoers_fragment EXIT

echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" | sudo tee "$SUDOERS_D_FRAGMENT" >/dev/null
sudo chmod 0440 "$SUDOERS_D_FRAGMENT"
sudo visudo -c >/dev/null 2>&1 && echo "✅ Temporary sudo access granted."

###############################################################################
# 3. Udev Rules for Backlight
###############################################################################
UDEV_RULES_DIR="/etc/udev/rules.d"
sudo mkdir -p "$UDEV_RULES_DIR"
UDEV_RULES_FILE="$UDEV_RULES_DIR/90-backlight.rules"

cat <<'EOF' | sudo tee "$UDEV_RULES_FILE" >/dev/null
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF

sudo udevadm control --reload
sudo udevadm trigger
echo "✅ Udev rules for backlight applied."

###############################################################################
# 4. Add User to Groups
###############################################################################
GROUPS_TO_ADD="video lp input"
for group in $GROUPS_TO_ADD; do
  if id -nG "$TARGET_USER" | grep -qw "$group"; then
    echo "User $TARGET_USER already in group: $group."
  else
    sudo usermod -a -G "$group" "$TARGET_USER"
    echo "Added user $TARGET_USER to group: $group."
  fi
done

###############################################################################
# 5. Run Installer Submodules
###############################################################################
INSTALLERS=(
  install-packages
  add-font
  audio-integration
  niri
  waybar
  hyprlock
  sddm_astronaut
  awww
  grub
  nvidia
  vulkan-intel
  intel
  dev-tools
  networkman
)

# Flag for child installers to detect parent
export PARENT_INSTALLER=1

for script in "${INSTALLERS[@]}"; do
  echo "⚙️ Running installer: $script.sh ..."
  if [[ ! -f "./installers/$script.sh" ]]; then
    echo "⚠️ Missing installer script: $script.sh — skipping."
    continue
  fi

  chmod +x "./installers/$script.sh"

  if [[ "$script" =~ install-packages|grub|networkman ]]; then
    sudo PARENT_INSTALLER=1 "./installers/$script.sh"
  else
    PARENT_INSTALLER=1 "./installers/$script.sh" "$TARGET_USER" "$TARGET_USER_HOME"
  fi

  echo "✅ $script.sh completed successfully!"
done

unset PARENT_INSTALLER

###############################################################################
# 6. Enable System Services
###############################################################################
SERVICE_DIR="/var/service"
enable_service() {
  local name="$1"
  local src="/etc/sv/$name"
  local dest="$SERVICE_DIR/$name"
  if [[ -d "$src" || -L "$src" ]]; then
    [[ -L "$dest" ]] || sudo ln -sf "$src" "$dest"
    echo "✅ Enabled $name service."
  else
    echo "⚠️ Service $name not found at $src."
  fi
}

enable_service power-profiles-daemon
enable_service NetworkManager
enable_service dbus

###############################################################################
# 7. Wrap-up
###############################################################################
set +x
echo
echo "🎉 Installation complete!"
echo "Log saved at: $LOG_FILE"
echo "Reboot recommended."
echo "------------------------------------------------------------"
echo "Ended at: $(date)"
