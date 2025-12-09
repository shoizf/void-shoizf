#!/usr/bin/env bash
# installers/vulkan.sh — Vulkan ICD verification for Intel/NVIDIA systems
# ROOT-SCRIPT — diagnostics only (no package installs performed)

# NOTE: We do NOT use `set -e` here.
# Vulkan is optional for many users, and failed checks should NOT kill install.
set -uo pipefail

# ------------------------------------------------------
# 1. CONTEXT NORMALIZATION
# ------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

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

# ------------------------------------------------------
# Logging helpers
# ------------------------------------------------------
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" >> "$LOG_FILE"
  [ "$QUIET_MODE" = false ] && echo "$msg"
}

info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok()    { log "OK    $*"; }
pp()    { echo -e "$*"; }

pp "▶ $SCRIPT_NAME"
log "▶ Starting $SCRIPT_NAME"
info "Target user: $TARGET_USER"
info "Target home: $TARGET_HOME"

# ------------------------------------------------------
# 1.5 VM DETECTION — SKIP IF VM
# ------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$REPO_ROOT/utils/is_vm.sh" ]; then
  # shellcheck source=/dev/null
  source "$REPO_ROOT/utils/is_vm.sh"
else
  warn "utils/is_vm.sh missing — assuming bare metal"
  IS_VM=false
fi

if [ "${IS_VM:-false}" = true ]; then
  info "VM detected — skipping Vulkan checks"
  pp "⚠ $SCRIPT_NAME skipped (running inside VM)"
  log "✔ Finished $SCRIPT_NAME (skipped for VM)"
  exit 0
fi

# ------------------------------------------------------
# 2. ROOT VALIDATION
# ------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  pp "❌ vulkan.sh: needs root"
  error "Script must be executed as root"
  exit 1
fi

info "NOTE: Vulkan packages are installed in packages.sh — this script only checks."

# ------------------------------------------------------
# 3. ICD DETECTION
# ------------------------------------------------------
ICD_DIR="/usr/share/vulkan/icd.d"

if [ ! -d "$ICD_DIR" ]; then
  warn "ICD directory is missing — no Vulkan support installed"
  pp "⚠ Vulkan ICD directory not found — Vulkan unavailable"
  log "✔ Finished $SCRIPT_NAME (no ICD directory)"
  exit 0
fi

INTEL_ICD=$(ls "$ICD_DIR"/*intel*.json 2>/dev/null || true)
NVIDIA_ICD=$(ls "$ICD_DIR"/*nvidia*.json 2>/dev/null || true)

# Intel ICD
if [ -n "$INTEL_ICD" ]; then
  ok "Intel ICD: $(basename "$INTEL_ICD")"
else
  warn "Intel Vulkan ICD missing (mesa-vulkan-intel required)"
fi

# NVIDIA ICD
if [ -n "$NVIDIA_ICD" ]; then
  ok "NVIDIA ICD: $(basename "$NVIDIA_ICD")"
else
  warn "NVIDIA Vulkan ICD missing (offload Vulkan will NOT work)"
fi

# Summary condition
if [ -n "$INTEL_ICD" ] && [ -n "$NVIDIA_ICD" ]; then
  info "Hybrid Vulkan stack detected (Intel primary + NVIDIA offload)"
elif [ -n "$INTEL_ICD" ]; then
  warn "Only Intel Vulkan ICD found — no NVIDIA Vulkan offload"
elif [ -n "$NVIDIA_ICD" ]; then
  warn "Only NVIDIA Vulkan ICD found — desktop compositors may break"
else
  warn "No Vulkan ICDs found — Vulkan unavailable"
fi

# ------------------------------------------------------
# 4. OPTIONAL: vulkaninfo check
# ------------------------------------------------------
if command -v vulkaninfo >/dev/null 2>&1; then
  info "Running vulkaninfo --summary..."
  if vulkaninfo --summary >> "$LOG_FILE" 2>&1; then
    ok "vulkaninfo executed successfully"
  else
    warn "vulkaninfo reports issues — Vulkan may be incomplete"
  fi
else
  warn "vulkaninfo not installed (package: vulkan-tools)"
fi

# ------------------------------------------------------
# 6. END
# ------------------------------------------------------
log "✔ Finished $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
