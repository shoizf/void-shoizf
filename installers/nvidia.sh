#!/usr/bin/env bash
# installers/nvidia.sh — Configure NVIDIA PRIME Render Offload (Intel primary + NVIDIA secondary)
# ROOT-SCRIPT — must be run as root via install.sh only

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT & LOGGING
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Determine correct user's home for logging (same logic as other root scripts)
if [ -n "${TARGET_HOME:-}" ]; then
    TARGET_USER_HOME="$TARGET_HOME"
elif [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    TARGET_USER_HOME="/root"
fi

# Logging: master mode or standalone fallback
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
    LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
    MASTER_MODE=true
else
    LOG_DIR="$TARGET_USER_HOME/.local/log/void-shoizf"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
    MASTER_MODE=false
fi

QUIET_MODE=${QUIET_MODE:-true}

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
    echo "$msg" >>"$LOG_FILE"
    if [ "$QUIET_MODE" = false ] && [ "$MASTER_MODE" = false ]; then
        echo "$msg"
    fi
}

info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*"; exit 1; }
ok()    { log "OK    $*"; }
pp()    { echo -e "$*"; }

pp "▶ $SCRIPT_NAME"
log "▶ Starting NVIDIA PRIME offload configuration"

# ------------------------------------------------------
# 2. VALIDATION
# ------------------------------------------------------

[ "$EUID" -ne 0 ] && error "This script must run as root"

# ------------------------------------------------------
# 3. VM DETECTION — ALWAYS SKIP IN VM
# ------------------------------------------------------

# install.sh already exports IS_VM when sourcing utils/is_vm.sh
if [ "${IS_VM:-false}" = true ]; then
    warn "VM detected — skipping NVIDIA configuration entirely"
    log  "SKIP: NVIDIA script disabled inside virtual machines"
    pp   "⚠ Skipping NVIDIA config (VM detected)"
    exit 0
fi

# ------------------------------------------------------
# 4. GPU DETECTION
# ------------------------------------------------------

command -v lspci >/dev/null 2>&1 || warn "lspci not available — pciutils missing"
command -v xbps-query >/dev/null 2>&1 || warn "xbps-query missing — cannot verify driver packages"

info "Detecting GPUs…"

NVIDIA_ADDR="$(lspci -nn | grep -i 'nvidia' | awk '{print $1}' | head -n1 || true)"
INTEL_ADDR="$(lspci -nn | grep -i 'intel' | grep -E 'VGA|3D' | awk '{print $1}' | head -n1 || true)"

if [ -z "$NVIDIA_ADDR" ]; then
    warn "No NVIDIA GPU detected — skipping"
    exit 0
fi

info "NVIDIA GPU: $NVIDIA_ADDR"
[ -n "$INTEL_ADDR" ] && info "Intel GPU:   $INTEL_ADDR"

pci_to_busid() {
    IFS=':.' read -r bus dev func <<<"$1"
    printf 'PCI:%d:%d:%d' $((0x$bus)) $((0x$dev)) $((0x$func))
}

NVIDIA_BUSID="$(pci_to_busid "$NVIDIA_ADDR")"
info "NVIDIA BusID resolved to $NVIDIA_BUSID"

# ------------------------------------------------------
# 5. BLACKLIST NOUVEAU (required by proprietary driver)
# ------------------------------------------------------

BLACKLIST_FILE="/etc/modprobe.d/blacklist-nouveau.conf"
info "Blacklisting nouveau → $BLACKLIST_FILE"

cat >"$BLACKLIST_FILE" <<'EOF'
# Managed by void-shoizf
blacklist nouveau
options nouveau modeset=0
EOF

chmod 644 "$BLACKLIST_FILE"
ok "Nouveau blacklisted"

# ------------------------------------------------------
# 6. XORG PRIME OFFLOAD CONFIG
# ------------------------------------------------------

XORG_DIR="/etc/X11/xorg.conf.d"
XORG_FILE="$XORG_DIR/10-nvidia-prime.conf"

mkdir -p "$XORG_DIR"
info "Writing PRIME offload config → $XORG_FILE"

cat >"$XORG_FILE" <<EOF
# Managed by void-shoizf — PRIME Render Offload
Section "Device"
    Identifier "IntelGPU"
    Driver     "modesetting"
EndSection

Section "Device"
    Identifier "NvidiaGPU"
    Driver     "nvidia"
    BusID      "$NVIDIA_BUSID"
    Option     "AllowEmptyInitialConfiguration" "true"
EndSection
EOF

chmod 644 "$XORG_FILE"
ok "Xorg PRIME config installed"

# ------------------------------------------------------
# 7. PRIME-RUN WRAPPER (Void Linux recommended)
# ------------------------------------------------------

PRIME_RUN="/usr/local/bin/prime-run"
info "Installing prime-run wrapper → $PRIME_RUN"

cat >"$PRIME_RUN" <<'EOF'
#!/usr/bin/env bash
# Run program on the NVIDIA GPU
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
exec "$@"
EOF

chmod 755 "$PRIME_RUN"
ok "prime-run ready (use: prime-run <app>)"

# ------------------------------------------------------
# 8. GRUB SETTINGS — enable NVIDIA DRM modeset
# ------------------------------------------------------

GRUB_FILE="/etc/default/grub"
GRUB_PARAM="nvidia-drm.modeset=1"

if [ -f "$GRUB_FILE" ]; then
    info "Ensuring GRUB contains: $GRUB_PARAM"

    if ! grep -q "$GRUB_PARAM" "$GRUB_FILE"; then
        sed -i "s|\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"|\1 $GRUB_PARAM\"|" "$GRUB_FILE"
        ok "Added GRUB param"
    else
        info "GRUB param already present"
    fi

    if command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg >>"$LOG_FILE" 2>&1 \
            && ok "grub.cfg regenerated" \
            || warn "grub-mkconfig failed (check EFI mount)"
    fi
else
    warn "Missing /etc/default/grub — skipping GRUB edits"
fi

# ------------------------------------------------------
# 9. VULKAN ICD CHECK
# ------------------------------------------------------

if compgen -G "/usr/share/vulkan/icd.d/*nvidia*.json" >/dev/null; then
    ok "Vulkan NVIDIA ICD present"
else
    warn "Missing Vulkan NVIDIA ICD — Vulkan offload may not function"
fi

# ------------------------------------------------------
# 10. END
# ------------------------------------------------------

log "✔ NVIDIA PRIME Render Offload configuration complete"
pp "✔ NVIDIA PRIME configured (Intel primary → NVIDIA offload)"
pp "→ Run apps with: prime-run <program>"
exit 0
