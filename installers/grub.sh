#!/usr/bin/env bash
# installers/grub.sh — install & configure GRUB (EFI)
# ROOT-SCRIPT — must be executed as root by install.sh

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Determine correct user's home for logging (not for data)
if [ -n "${TARGET_HOME:-}" ]; then
  LOG_USER_HOME="$TARGET_HOME"
elif [ -n "${SUDO_USER:-}" ]; then
  LOG_USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  LOG_USER_HOME="/root"
fi

# Master mode vs standalone mode
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
  MASTER_MODE=true
else
  LOG_DIR="$LOG_USER_HOME/.local/log/void-shoizf"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
  MASTER_MODE=false
fi

QUIET_MODE=${QUIET_MODE:-true}

# ------------------------------------------------------
# 2. LOGGING HELPERS
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
# 3. STARTUP & VALIDATION
# ------------------------------------------------------
pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"

if [ "$EUID" -ne 0 ]; then
  error "grub.sh must be run as root (via install.sh ROOT_SCRIPTS)"
  pp "❌ grub: need root"
  exit 1
fi

# ------------------------------------------------------
# 4. WORKDIR
# ------------------------------------------------------
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
info "Workdir: $WORKDIR"

# ------------------------------------------------------
# 5. DEPENDENCY CHECK
# ------------------------------------------------------
info "Checking required GRUB dependencies…"

MISSING=()

check_dep() {
  if ! command -v "$1" >/dev/null 2>&1; then
    MISSING+=("$1")
  fi
}

# executables required
check_dep grub-install
check_dep grub-mkconfig
check_dep os-prober
check_dep efibootmgr

# packages whose executables may not expose commands
[ -f /boot/efi ] || warn "/boot/efi not mounted (installer may fail)"

if [ ${#MISSING[@]} -gt 0 ]; then
  error "Missing required dependencies:"
  for dep in "${MISSING[@]}"; do
    error "  - $dep"
  done
  error "Install missing packages via packages.sh"
  pp "❌ grub.sh: missing dependencies (see log)"
  exit 1
fi

ok "All GRUB dependencies available"

# ------------------------------------------------------
# 6. THEME INSTALLATION
# ------------------------------------------------------
THEME_DIR="/boot/grub/themes/crossgrub"
THEME_REPO="https://github.com/krypciak/crossgrub.git"

info "Cloning GRUB theme…"
if git clone --depth 1 "$THEME_REPO" "$WORKDIR/theme" >>"$LOG_FILE" 2>&1; then
  rm -rf "$THEME_DIR" || true
  mkdir -p "$THEME_DIR"
  cp -r "$WORKDIR/theme/"* "$THEME_DIR/" >>"$LOG_FILE" 2>&1
  ok "GRUB theme installed → $THEME_DIR"
else
  warn "Theme clone failed — skipping theme setup"
fi

# ------------------------------------------------------
# 7. UPDATE /etc/default/grub
# ------------------------------------------------------
info "Updating /etc/default/grub settings…"

GRUB_CFG="/etc/default/grub"
THEME_TXT="$THEME_DIR/theme.txt"

# Ensure GRUB_THEME
if grep -q '^GRUB_THEME=' "$GRUB_CFG" 2>/dev/null; then
  sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_TXT\"|" "$GRUB_CFG"
else
  echo "GRUB_THEME=\"$THEME_TXT\"" >>"$GRUB_CFG"
fi
ok "GRUB_THEME set"

# Ensure GRUB_DISABLE_OS_PROBER=false
if grep -q '^GRUB_DISABLE_OS_PROBER=' "$GRUB_CFG"; then
  sed -i "s|^GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|" "$GRUB_CFG"
else
  echo "GRUB_DISABLE_OS_PROBER=false" >>"$GRUB_CFG"
fi
ok "OS prober enabled"

# ------------------------------------------------------
# 8. grub-install (EFI)
# ------------------------------------------------------
info "Running grub-install…"
if grub-install --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=shoizf \
  --recheck >>"$LOG_FILE" 2>&1; then
  ok "grub-install completed"
else
  warn "grub-install failed (see log) — maybe missing EFI mount?"
fi

# ------------------------------------------------------
# 9. Generate grub.cfg
# ------------------------------------------------------
info "Running grub-mkconfig…"
if grub-mkconfig -o /boot/grub/grub.cfg >>"$LOG_FILE" 2>&1; then
  ok "grub.cfg generated"
else
  warn "Failed to generate grub.cfg — see log"
fi

log "Summary: theme=$THEME_DIR, grub.cfg=/boot/grub/grub.cfg"

# ------------------------------------------------------
# 10. FINISH
# ------------------------------------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
