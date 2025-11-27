#!/usr/bin/env bash
# installers/sddm_astronaut.sh — install SDDM astronaut theme + Jake-the-Dog preset
# USER-SCRIPT (run as normal user, uses sudo internally)

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

LOG_DIR="$HOME/.local/state/void-shoizf/log"
mkdir -p "$LOG_DIR"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

QUIET_MODE=${QUIET_MODE:-true}

# ------------------------------------------------------
# 2. LOGGING HELPERS
# ------------------------------------------------------

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
log "▶ Starting installer: $SCRIPT_NAME"

# ------------------------------------------------------
# 3. VALIDATION
# ------------------------------------------------------

if [ "$EUID" -eq 0 ]; then
  warn "$SCRIPT_NAME should be run as a normal user"
fi

# ------------------------------------------------------
# 4. INSTALL SDDM + QT MODULES
# ------------------------------------------------------

info "Installing SDDM & Qt6 dependencies..."
sudo xbps-install -yN sddm qt6-svg qt6-virtualkeyboard qt6-multimedia || warn "Some Qt dependencies had issues"

# ------------------------------------------------------
# 5. THEME INSTALLATION
# ------------------------------------------------------

THEME_BASE="/usr/share/sddm/themes"
THEME_NAME="sddm-astronaut-theme"
THEME_DIR="$THEME_BASE/$THEME_NAME"

if [ ! -d "$THEME_DIR" ]; then
  info "Cloning astronaut theme..."
  sudo git clone --depth 1 https://github.com/Keyitdev/sddm-astronaut-theme.git "$THEME_DIR"
  ok "Theme installed into $THEME_DIR"
else
  info "Theme already installed → $THEME_DIR"
fi

# ------------------------------------------------------
# 6. SET THE JAKE-THE-DOG PRESET
# ------------------------------------------------------

TARGET_PRESET="jake_the_dog.conf"
TARGET_PATH="Themes/$TARGET_PRESET"
METADATA_FILE="$THEME_DIR/metadata.desktop"

if [ ! -f "$THEME_DIR/$TARGET_PATH" ]; then
  warn "Jake-the-Dog preset not found: $TARGET_PATH"
  warn "Available presets: $(ls "$THEME_DIR/Themes")"
else
  info "Applying Jake-the-Dog preset..."

  # Replace ConfigFile= line
  sudo sed -i "s|^ConfigFile=.*|ConfigFile=$TARGET_PATH|" "$METADATA_FILE"

  ok "Preset set to $TARGET_PRESET"
fi

# ------------------------------------------------------
# 7. INSTALL FONTS USED BY THEME
# ------------------------------------------------------

if [ -d "$THEME_DIR/Fonts" ]; then
  info "Copying theme fonts..."
  sudo cp -r "$THEME_DIR/Fonts/"* /usr/share/fonts/
  sudo fc-cache -f
  ok "Fonts installed"
else
  warn "Theme has no Fonts directory"
fi

# ------------------------------------------------------
# 8. WRITE SDDM CONFIG
# ------------------------------------------------------

info "Writing /etc/sddm.conf"

sudo tee /etc/sddm.conf >/dev/null <<EOF
[Theme]
Current=$THEME_NAME
ConfigFile=$TARGET_PATH
EOF

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/virtualkbd.conf >/dev/null <<EOF
[General]
InputMethod=qtvirtualkeyboard
EOF

ok "SDDM config applied"

# ------------------------------------------------------
# 9. ENABLE + RESTART SDDM SERVICE
# ------------------------------------------------------

if [ ! -L /var/service/sddm ]; then
  info "Enabling SDDM..."
  sudo ln -sf /etc/sv/sddm /var/service/
fi

info "Restarting SDDM service"
sudo sv restart sddm || warn "Could not restart sddm (may not be running)"

# ------------------------------------------------------
# 10. END
# ------------------------------------------------------

log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ SDDM astronaut theme installed (Jake-the-Dog preset active)"
exit 0
