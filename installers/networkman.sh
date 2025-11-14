#!/usr/bin/env bash
# installers/networkman.sh — install & configure NetworkManager for Void
# This script is VM-aware: on VMs we will not replace running wpa_supplicant service

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

log "▶ networkman.sh starting"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../utils/is_vm.sh" ]; then
  source "$SCRIPT_DIR/../utils/is_vm.sh" || true
else
  IS_VM=false
fi
log "INFO IS_VM=${IS_VM}"

if [ "$EUID" -ne 0 ]; then
  log "ERROR networkman.sh must be run as root. Exiting."
  exit 1
fi

log "INFO Installing NetworkManager packages"
xbps-install -Sy --yes NetworkManager networkmanager-dmenu nm-tray || log "WARN NM packages may have failed"

# Detect virtualization (informational only)
if systemd-detect-virt >/dev/null 2>&1; then
  log "INFO VM detected — configuring minimal Ethernet/NAT setup"
else
  log "INFO Bare-metal hardware detected — configuring full NetworkManager setup"
fi

# Configure internal DHCP for NM
CONF_DIR="/etc/NetworkManager/conf.d"
CONF_FILE="$CONF_DIR/90-internal-dhcp.conf"
mkdir -p "$CONF_DIR"
cat >"$CONF_FILE" <<EOF
[main]
dhcp=internal
EOF

# Handle runit services
if [[ "$IS_VM" == true ]]; then
  log "INFO VM detected — will NOT remove wpa_supplicant or dhcpcd"
else
  if [ -L /var/service/dhcpcd ]; then
    rm -f /var/service/dhcpcd || true
    log "OK removed dhcpcd runit link"
  fi
  if [ -L /var/service/wpa_supplicant ]; then
    rm -f /var/service/wpa_supplicant || true
    log "OK removed wpa_supplicant runit link"
  fi
  if [ -f /etc/resolv.conf ]; then
    mv /etc/resolv.conf /etc/resolv.conf.old || true
    log "OK backed up resolv.conf"
  fi
fi

log "INFO Enabling NetworkManager service"
ln -sf /etc/sv/NetworkManager /var/service || true

log "✅ networkman.sh finished"
