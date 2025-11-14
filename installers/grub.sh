#!/usr/bin/env bash
# installers/grub.sh — install & configure GRUB (EFI)

set -euo pipefail

LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
MASTER_LOG="$LOG_DIR/master-install.log"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE" >>"$MASTER_LOG"
}

log "▶ grub.sh starting"

if [ "$EUID" -eq 0 ]; then
  log "INFO Running as root (required for grub install)"
else
  log "ERROR grub.sh must be invoked with sudo/root"
  exit 1
fi

set -x
# Install packages
xbps-install -Sy --yes intel-ucode grub-x86_64-efi os-prober || log "WARN grub packages installation had issues"

THEME_DIR="/boot/grub/themes/crossgrub"
THEME_REPO="https://github.com/krypciak/crossgrub.git"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if git clone --depth 1 "$THEME_REPO" "$WORKDIR"; then
  rm -rf "$THEME_DIR" || true
  mkdir -p "$THEME_DIR"
  cp -r "$WORKDIR"/* "$THEME_DIR/" || true
  log "OK GRUB theme installed to $THEME_DIR"
else
  log "WARN Could not clone GRUB theme"
fi

# Configure defaults
if ! grep -q '^GRUB_THEME=' /etc/default/grub 2>/dev/null; then
  echo "GRUB_THEME=\"${THEME_DIR}/theme.txt\"" >>/etc/default/grub
else
  sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${THEME_DIR}/theme.txt\"|" /etc/default/grub
fi

if ! grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub 2>/dev/null; then
  echo "GRUB_DISABLE_OS_PROBER=false" >>/etc/default/grub
else
  sed -i "s|^GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|" /etc/default/grub
fi

# Install grub to EFI (best-effort)
if ! grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=shoizf --recheck; then
  log "WARN grub-install failed (check EFI mount)"
else
  log "OK grub-install completed"
fi

if grub-mkconfig -o /boot/grub/grub.cfg; then
  log "OK grub config generated"
else
  log "WARN grub-mkconfig failed"
fi

log "✅ grub.sh finished"
