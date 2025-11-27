#!/usr/bin/env bash
# installers/networkman.sh — configure NetworkManager on Void
# ROOT-SCRIPT (must be executed as root by install.sh)

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

if [ -n "${SUDO_USER:-}" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_HOME="$HOME"
fi

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
  MASTER_MODE=true
else
  LOG_DIR="$USER_HOME/.local/log/void-shoizf"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
  MASTER_MODE=false
fi

QUIET_MODE=${QUIET_MODE:-true}

# ------------------------------------------------------
# 2. LOGGING FUNCTIONS
# ------------------------------------------------------
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >>"$LOG_FILE"
  if [ "$QUIET_MODE" = false ] && [ "$MASTER_MODE" = false ]; then echo "$msg"; fi
}
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok() { log "OK    $*"; }
pp() { echo -e "$*"; }

# ------------------------------------------------------
# 3. STARTUP
# ------------------------------------------------------
pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"

if [ "$EUID" -ne 0 ]; then
  error "networkman.sh must be run as root"
  exit 1
fi

# VM detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../utils/is_vm.sh" ]; then
  source "$SCRIPT_DIR/../utils/is_vm.sh" || true
else
  IS_VM=false
fi
info "IS_VM=${IS_VM}"

# ------------------------------------------------------
# 4. PACKAGE INSTALL REMOVED (handled by packages.sh)
# ------------------------------------------------------
info "NetworkManager packages are assumed installed by packages.sh"

# ------------------------------------------------------
# 5. CONFIGURE NETWORKMANAGER
# ------------------------------------------------------
CONF_DIR="/etc/NetworkManager/conf.d"
CONF_FILE="$CONF_DIR/90-internal-dhcp.conf"

mkdir -p "$CONF_DIR"
info "Writing DHCP internal config → $CONF_FILE"

cat >"$CONF_FILE" <<EOF
[main]
dhcp=internal
EOF
ok "DHCP config applied"

# ------------------------------------------------------
# 6. HANDLE SERVICES
# ------------------------------------------------------
if [ "$IS_VM" = true ]; then
  info "VM detected — preserving dhcpcd & wpa_supplicant"
else
  if [ -L /var/service/dhcpcd ]; then
    rm -f /var/service/dhcpcd
    ok "Removed dhcpcd service"
  fi

  if [ -L /var/service/wpa_supplicant ]; then
    rm -f /var/service/wpa_supplicant
    ok "Removed wpa_supplicant service"
  fi

  if [ -f /etc/resolv.conf ]; then
    mv /etc/resolv.conf /etc/resolv.conf.old || true
    ok "Backed up resolv.conf"
  fi
fi

# Enable NM service
if [ -d /etc/sv/NetworkManager ]; then
  ln -sf /etc/sv/NetworkManager /var/service
  ok "NetworkManager service enabled"
else
  error "/etc/sv/NetworkManager not found — cannot enable"
fi

# ------------------------------------------------------
# 7. END
# ------------------------------------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
