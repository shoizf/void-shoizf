#!/usr/bin/env bash
# installers/hyprlock.sh — install hyprlock/hypridle configs, helpers & assets
# Run as ROOT. Grants sleep permissions and installs user configs safely.

set -euo pipefail

# --- 1. USER DETECTION (Crucial for Standalone Root Run) ---
# If running from install.sh, TARGET_USER is set.
# If running standalone via sudo, we must detect the real user.
if [ -n "${TARGET_USER:-}" ]; then
  # Inherited from install.sh
  USER_HOME="$TARGET_HOME"
else
  # Standalone Root run - detect SUDO_USER
  if [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  else
    echo "❌ Error: When running standalone, use sudo."
    echo "   Ex: sudo ./installers/hyprlock.sh"
    exit 1
  fi
fi

# --- 2. LOGGING SETUP ---
LOG_BASE="$USER_HOME/.local/state/void-shoizf/log"
mkdir -p "$LOG_BASE"
SCRIPT_NAME="$(basename "$0" .sh)"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  # SCENARIO A: Parent-driven (Append to master log)
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  # SCENARIO B: Standalone (Create unique log)
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_BASE/${SCRIPT_NAME}-${TIMESTAMP}.log"

  # FIX: Create the file first, THEN chown it
  touch "$LOG_FILE"
  chown "$TARGET_USER" "$LOG_BASE" "$LOG_FILE"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

log "▶ hyprlock.sh starting (Root Mode)"

if [ "$EUID" -ne 0 ]; then
  log "ERROR hyprlock.sh must be run as ROOT to configure sudoers."
  exit 1
fi

# --- 3. CONFIGURE SYSTEM PERMISSIONS (The Root Task) ---
SUDO_RULE="ALL ALL=(ALL) NOPASSWD: /usr/bin/zzz"
SUDO_FILE="/etc/sudoers.d/void-shoizf-zzz"

if [ ! -f "$SUDO_FILE" ]; then
  log "Configuring NOPASSWD for zzz (suspend)..."
  echo "$SUDO_RULE" >"$SUDO_FILE"
  chmod 440 "$SUDO_FILE"
  log "Permission granted: $SUDO_FILE"
else
  log "Sudoers rule already exists."
fi

# --- 4. DEFINE USER PATHS ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_DIR" == */installers ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  REPO_ROOT="$(pwd)"
fi

HYPR_CONFIG_DIR="$USER_HOME/.config/hypr"
ASSETS_DIR="$USER_HOME/.local/share/hypr/assets"
BIN_DIR="$USER_HOME/.local/bin"

# --- 5. INSTALL HELPER SCRIPTS (With User Ownership) ---
log "Installing helper scripts..."
HELPER_SCRIPTS=("battery-status.sh" "music-info.sh" "music-progress.sh" "shoizf-lock")

for script in "${HELPER_SCRIPTS[@]}"; do
  SRC="$REPO_ROOT/bin/$script"
  DEST="$BIN_DIR/$script"
  if [ -f "$SRC" ]; then
    # install -D creates destination dirs if missing
    install -D -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$SRC" "$DEST"
    log "OK Installed $script"
  else
    log "WARN Missing script: $SRC"
  fi
done

# --- 6. INSTALL ASSETS ---
SRC_BG="$REPO_ROOT/configs/hypr/assets/hyprlockbg.jpg"
DEST_BG="$ASSETS_DIR/hyprlockbg.jpg"

if [ -f "$SRC_BG" ]; then
  install -D -m 644 -o "$TARGET_USER" -g "$TARGET_USER" "$SRC_BG" "$DEST_BG"
  log "OK Background installed"
else
  log "WARN Background missing"
fi

# --- 7. INSTALL HYPRLOCK CONFIG ---
SOURCE_LOCK="$REPO_ROOT/configs/hypr/hyprlock.conf"
DEST_LOCK="$HYPR_CONFIG_DIR/hyprlock.conf"

if [ -f "$SOURCE_LOCK" ]; then
  TMP_LOCK="$(mktemp)"
  # Fix path: Replace ~/.local... with actual absolute path for safety
  sed "s|~/.local/share/hypr/assets/hyprlockbg.jpg|$DEST_BG|g" "$SOURCE_LOCK" >"$TMP_LOCK"

  install -D -m 644 -o "$TARGET_USER" -g "$TARGET_USER" "$TMP_LOCK" "$DEST_LOCK"
  rm "$TMP_LOCK"
  log "OK hyprlock.conf installed"
else
  log "WARN hyprlock.conf missing"
fi

# --- 8. CONFIGURE HYPRIDLE ---
TEMPLATE_IDLE="$REPO_ROOT/configs/hypr/hypridle.conf.template"
DEST_IDLE="$HYPR_CONFIG_DIR/hypridle.conf"

DPMS_METHOD="none"
SCREEN_OFF="echo '[hyprlock] Screen off skipped'"
SCREEN_ON=":"
SUSPEND="echo '[hyprlock] Suspend skipped'"

# Environment checks (simple command check as root is sufficient for binaries)
if command -v niri >/dev/null 2>&1; then
  SCREEN_OFF="niri msg action power-off-monitors"
  log "INFO Detected Niri"
elif command -v wlr-randr >/dev/null 2>&1; then
  SCREEN_OFF="wlr-randr --output HEAD-0 --off"
  log "INFO Detected wlr-randr"
fi

if command -v zzz >/dev/null 2>&1; then
  SUSPEND="sudo zzz"
elif command -v systemctl >/dev/null 2>&1; then SUSPEND="systemctl suspend"; fi

if [ -f "$TEMPLATE_IDLE" ]; then
  TMP_IDLE="$(mktemp)"
  sed -e "s|__SCREEN_OFF_CMD__|$SCREEN_OFF|g" \
    -e "s|__SCREEN_ON_CMD__|$SCREEN_ON|g" \
    -e "s|__SUSPEND_CMD__|$SUSPEND|g" \
    "$TEMPLATE_IDLE" >"$TMP_IDLE"

  install -D -m 644 -o "$TARGET_USER" -g "$TARGET_USER" "$TMP_IDLE" "$DEST_IDLE"
  rm "$TMP_IDLE"
  log "OK hypridle.conf generated"
else
  log "ERROR hypridle template missing"
fi

log "✅ hyprlock.sh finished"
