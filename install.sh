#!/bin/bash
###############################################################################
# Main installation script for void-shoizf setup
# Logs everything to a timestamped file outside the working directory.
# Run as a normal user (not root).
###############################################################################

set -euo pipefail

# --- Logging Setup ---
LOG_DIR="/var/log/void-shoizf"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$LOG_DIR/install_${TIMESTAMP}.log"

# Try to create /var/log path with sudo if possible
if ! sudo mkdir -p "$LOG_DIR" 2>/dev/null || [ ! -w "$LOG_DIR" ]; then
  LOG_DIR="$HOME/.local/logs/void-shoizf"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/install_${TIMESTAMP}.log"
fi

# Create or touch the log file, append all output
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "📘 Logging installation to: $LOG_FILE"
echo "Starting void-shoizf setup at $(date)"
echo "---------------------------------------------"

# --- Backup sudoers file & grant passwordless sudo temporarily ---
SUDOERS_BACKUP="/etc/sudoers.bak_$TIMESTAMP"

echo "🔐 Backing up sudoers file to $SUDOERS_BACKUP"
sudo cp /etc/sudoers "$SUDOERS_BACKUP"

CURRENT_USER="$(whoami)"
echo "🧩 Temporarily allowing passwordless sudo for $CURRENT_USER"
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/void-shoizf-temp >/dev/null

# --- Core installer logic begins here ---
echo "🚀 Running component installers..."

if ./installers/networkmanager.sh; then
  echo "✅ NetworkManager installed successfully."
else
  echo "❌ NetworkManager installation failed!"
fi

# --- Enable System Services (runit) ---
echo "⚙️  Enabling system services (runit)..."
SERVICE_DIR="/var/service"

enable_service() {
  local service_name="$1"
  local service_path="/etc/sv/$service_name"
  local target_link="$SERVICE_DIR/$service_name"

  if [ ! -d "$service_path" ]; then
    echo "❓ Service definition not found: $service_path"
    return 1
  fi

  if [ ! -L "$target_link" ]; then
    echo "🔗 Enabling $service_name service..."
    sudo ln -sf "$service_path" "$SERVICE_DIR/"
  else
    echo "✅ $service_name service already enabled."
  fi
}

enable_service power-profiles-daemon
enable_service NetworkManager
enable_service dbus

echo "✅ System services checked/enabled."
echo "---------------------------------------------"

# --- Cleanup sudoers modification ---
echo "♻️  Restoring original sudoers configuration..."
sudo rm -f /etc/sudoers.d/void-shoizf-temp

if [ -f "$SUDOERS_BACKUP" ]; then
  echo "✅ sudoers restored successfully from $SUDOERS_BACKUP"
else
  echo "⚠️  Warning: sudoers backup not found — manual verification recommended!"
fi

# --- Final messages ---
echo "🎉 Main installation script completed!"
echo "📋 Logs saved at: $LOG_FILE"
echo "🌀 Please review and address any manual steps if required."
echo "💡 Waybar configuration needs to be updated manually."
echo "🔁 A final reboot is recommended."
