#!/usr/bin/env bash
# installers/nvidia.sh — Configure NVIDIA PRIME offload (Intel primary + NVIDIA secondary)
# ROOT-SCRIPT — must be run as root via install.sh

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT & LOGGING
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

if [ -n "${SUDO_USER:-}" ]; then
  TARGET_USER="$SUDO_USER"
  TARGET_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  TARGET_USER="$(whoami)"
  TARGET_USER_HOME="$HOME"
fi

LOG_DIR="$TARGET_USER_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

QUIET_MODE=${QUIET_MODE:-true}

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >>"$LOG_FILE"
  [ "$QUIET_MODE" = false ] && echo "$msg"
}

info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() {
  log "ERROR $*"
  exit 1
}
ok() { log "OK    $*"; }
pp() { echo -e "$*"; }

pp "▶ $SCRIPT_NAME"
log "▶ Starting NVIDIA PRIME offload configuration"

# ------------------------------------------------------
# 2. VALIDATION
# ------------------------------------------------------

[ "$EUID" -ne 0 ] && error "This script must run as root"

command -v lspci >/dev/null || warn "lspci not found — install pciutils for GPU detection"
command -v xbps-query >/dev/null || warn "xbps-query not found — cannot verify installed packages"

# ------------------------------------------------------
# 3. DETECT GPUs (NVIDIA + INTEL)
# ------------------------------------------------------

info "Detecting GPUs via lspci..."

NVIDIA_ADDR="$(lspci -nn | grep -i 'nvidia' | awk '{print $1}' | head -n1 || true)"
INTEL_ADDR="$(lspci -nn | grep -i 'intel' | grep -E 'VGA|3D' | awk '{print $1}' | head -n1 || true)"

if [ -z "$NVIDIA_ADDR" ]; then
  warn "No NVIDIA GPU detected — skipping NVIDIA configuration"
  exit 0
fi

info "NVIDIA GPU PCI address: $NVIDIA_ADDR"
[ -n "$INTEL_ADDR" ] && info "Intel GPU PCI address:   $INTEL_ADDR"

pci_to_busid() {
  local addr="$1"
  IFS=':.' read -r bus dev func <<<"$addr"
  printf 'PCI:%d:%d:%d' $((0x$bus)) $((0x$dev)) $((0x$func))
}

NVIDIA_BUSID="$(pci_to_busid "$NVIDIA_ADDR")"
info "NVIDIA BusID resolved to: $NVIDIA_BUSID"

# ------------------------------------------------------
# 4. BLACKLIST NOUVEAU
# ------------------------------------------------------

BLACKLIST_FILE="/etc/modprobe.d/blacklist-nouveau.conf"
info "Applying nouveau blacklist → $BLACKLIST_FILE"

cat >"$BLACKLIST_FILE" <<'EOF'
# Managed by void-shoizf
blacklist nouveau
options nouveau modeset=0
EOF

chmod 644 "$BLACKLIST_FILE"
ok "Nouveau blacklisted"

# ------------------------------------------------------
# 5. XORG PRIME OFFLOAD CONFIG
# ------------------------------------------------------

XORG_DIR="/etc/X11/xorg.conf.d"
XORG_FILE="$XORG_DIR/10-nvidia-prime.conf"
mkdir -p "$XORG_DIR"

info "Writing PRIME offload Xorg config → $XORG_FILE"

cat >"$XORG_FILE" <<EOF
# Managed by void-shoizf — PRIME offload config
Section "Device"
    Identifier  "IntelGPU"
    Driver      "modesetting"
EndSection

Section "Device"
    Identifier  "NvidiaGPU"
    Driver      "nvidia"
    BusID       "$NVIDIA_BUSID"
    Option      "AllowEmptyInitialConfiguration" "true"
EndSection
EOF

chmod 644 "$XORG_FILE"
ok "Xorg PRIME config installed"

# ------------------------------------------------------
# 6. INSTALL prime-run WRAPPER
# ------------------------------------------------------

PRIME_RUN="/usr/local/bin/prime-run"
info "Installing prime-run wrapper → $PRIME_RUN"

cat >"$PRIME_RUN" <<'EOF'
#!/usr/bin/env bash
# prime-run — Run program on NVIDIA dGPU
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
exec "$@"
EOF

chmod 755 "$PRIME_RUN"
ok "prime-run installed"

# ------------------------------------------------------
# 7. GRUB CONFIGURATION
# ------------------------------------------------------

GRUB_FILE="/etc/default/grub"
GRUB_PARAM="nvidia-drm.modeset=1"

if [ -f "$GRUB_FILE" ]; then
  info "Ensuring GRUB contains $GRUB_PARAM"
  if ! grep -q "$GRUB_PARAM" "$GRUB_FILE"; then
    sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 $GRUB_PARAM\"/" "$GRUB_FILE"
    ok "Inserted GRUB param"
  else
    info "GRUB param already present"
  fi
else
  warn "No /etc/default/grub found — skipping GRUB modification"
fi

if [ -f /boot/grub/grub.cfg ] || [ -d /boot/grub ]; then
  command -v grub-mkconfig >/dev/null && {
    grub-mkconfig -o /boot/grub/grub.cfg && ok "grub.cfg updated" ||
      warn "grub-mkconfig failed"
  }
fi

# ------------------------------------------------------
# 8. OPTIONAL CHECKS
# ------------------------------------------------------

if compgen -G "/usr/share/vulkan/icd.d/*nvidia*.json" >/dev/null; then
  ok "Vulkan NVIDIA ICD present"
else
  warn "NVIDIA Vulkan ICD missing — Vulkan offload may not work"
fi

# ------------------------------------------------------
# 9. DONE
# ------------------------------------------------------

log "NVIDIA PRIME offload configuration complete"
pp "✔ NVIDIA PRIME configured (intel → primary, nvidia → offload)"
pp "→ Use: prime-run <app>"
exit 0
