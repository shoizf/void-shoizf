#!/usr/bin/env bash
# installers/nvidia.sh — install NVIDIA driver stack (best-effort)

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

log "▶ nvidia.sh starting"

if [ "$EUID" -ne 0 ]; then
  log "ERROR nvidia.sh must be run as root. Exiting."
  exit 1
fi

KERNEL_VER="$(uname -r)"
KERNEL_PKG_BASE="$(echo "$KERNEL_VER" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')"
KERNEL_PKG="linux${KERNEL_PKG_BASE}"

log "INFO Installing kernel headers: ${KERNEL_PKG}-headers"
xbps-install -Sy --yes "${KERNEL_PKG}-headers" || log "WARN kernel headers install may have failed"

log "INFO Installing NVIDIA packages"
xbps-install -Sy --yes nvidia nvidia-dkms nvidia-firmware nvidia-gtklibs nvidia-libs nvidia-libs-32bit nvidia-vaapi-driver || log "WARN NVIDIA packages install may have issues"

# Blacklist nouveau
cat >/etc/modprobe.d/blacklist-nouveau.conf <<EOF
blacklist nouveau
options nouveau modeset=0
EOF
log "OK Blacklisted nouveau"

# Ensure grub param
if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub 2>/dev/null; then
  sed -i 's/ nvidia-drm.modeset=1//g' /etc/default/grub || true
  sed -i 's/nvidia-drm.modeset=1//g' /etc/default/grub || true
  sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"|GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"|' /etc/default/grub || true
  log "OK Added nvidia-drm.modeset=1 to GRUB_CMDLINE_LINUX_DEFAULT"
fi

if grub-mkconfig -o /boot/grub/grub.cfg; then
  log "OK grub-mkconfig updated"
else
  log "WARN grub-mkconfig failed"
fi

if xbps-reconfigure -f "$KERNEL_PKG"; then
  log "OK xbps-reconfigure completed"
else
  log "WARN xbps-reconfigure failed"
fi

log "✅ nvidia.sh finished (reboot recommended)"
