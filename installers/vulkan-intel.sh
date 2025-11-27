#!/usr/bin/env bash
# installers/vulkan-intel.sh — Vulkan ICD verification for Intel/NVIDIA hybrid systems
# ROOT-SCRIPT — invoked by install.sh (no package installs performed)

set -euo pipefail

# ------------------------------------------------------
# 1. CONTEXT NORMALIZATION
# ------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Determine user for logs
if [ -n "${SUDO_USER:-}" ]; then
  TARGET_USER="$SUDO_USER"
  TARGET_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  TARGET_USER="$(whoami)"
  TARGET_HOME="$HOME"
fi

LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

QUIET_MODE=${QUIET_MODE:-true}

# Logging helpers
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >>"$LOG_FILE"
  [ "$QUIET_MODE" = false ] && echo "$msg"
}
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok() { log "OK    $*"; }
pp() { echo -e "$*"; }

pp "▶ $SCRIPT_NAME"
log "▶ Starting $SCRIPT_NAME"
info "Target user: $TARGET_USER"
info "Target home: $TARGET_HOME"

# ------------------------------------------------------
# 2. VALIDATION
# ------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  error "This script must be executed as root (install.sh ROOT_SCRIPTS)"
  exit 1
fi

info "NOTE: Vulkan packages are handled by packages.sh — this script performs checks only."

# ------------------------------------------------------
# 3. DETECT ICDs
# ------------------------------------------------------
INTEL_ICD=$(ls /usr/share/vulkan/icd.d/*intel*.json 2>/dev/null || true)
NVIDIA_ICD=$(ls /usr/share/vulkan/icd.d/*nvidia*.json 2>/dev/null || true)

if [ -n "$INTEL_ICD" ]; then
  ok "Intel Vulkan ICD found: $(basename "$INTEL_ICD")"
else
  warn "Intel Vulkan ICD missing — install mesa-vulkan-intel if you need Intel Vulkan"
fi

if [ -n "$NVIDIA_ICD" ]; then
  ok "NVIDIA Vulkan ICD found: $(basename "$NVIDIA_ICD")"
else
  warn "NVIDIA Vulkan ICD missing — PRIME offload may fail"
fi

# Hybrid-specific warnings
if [ -n "$INTEL_ICD" ] && [ -n "$NVIDIA_ICD" ]; then
  info "Hybrid Vulkan stack detected (Intel primary + NVIDIA offload)."
elif [ -n "$INTEL_ICD" ] && [ -z "$NVIDIA_ICD" ]; then
  warn "Only Intel ICD present — NVIDIA offload will NOT expose Vulkan."
elif [ -z "$INTEL_ICD" ] && [ -n "$NVIDIA_ICD" ]; then
  warn "Only NVIDIA ICD present — desktop compositors may break (missing Intel ICD!)."
else
  error "No Vulkan ICDs found — Vulkan subsystem is NOT functional."
fi

# ------------------------------------------------------
# 4. Test Vulkan via vulkaninfo
# ------------------------------------------------------
if command -v vulkaninfo >/dev/null 2>&1; then
  info "Running vulkaninfo --summary..."
  if vulkaninfo --summary >>"$LOG_FILE" 2>&1; then
    ok "vulkaninfo executed successfully"
  else
    warn "vulkaninfo reported issues — Vulkan configuration may be incomplete"
  fi
else
  warn "vulkaninfo not installed — install vulkan-tools for debugging"
fi

# ------------------------------------------------------
# 5. Guidance (no environment tampering)
# ------------------------------------------------------
info "NOTE: VK_ICD_FILENAMES will NOT be set globally — this breaks hybrid setups."
info "Use per-app overrides only if needed:"
info "  VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json <app>"
info "For NVIDIA offload:"
info "  prime-run <app>"

# ------------------------------------------------------
# 6. END
# ------------------------------------------------------
log "✔ Finished $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
