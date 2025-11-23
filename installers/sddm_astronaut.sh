#!/usr/bin/env bash
# installers/sddm_astronaut.sh — install SDDM astronaut theme and enable jake-the-dog preset
# Run as USER. Uses sudo for system modifications.

set -euo pipefail

# --- Logging setup ---
LOG_DIR="$HOME/.local/state/void-shoizf/log"
mkdir -p "$LOG_DIR"
SCRIPT_NAME="$(basename "$0" .sh)"

if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
  LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

log "▶ sddm_astronaut.sh starting"

# --- 1. INSTALL PACKAGES ---
log "INFO Installing SDDM dependencies..."
sudo xbps-install -Sy --yes sddm qt6-svg qt6-virtualkeyboard qt6-multimedia || log "WARN SDDM packages issues"

# --- 2. CLONE THEME ---
THEME_BASE="/usr/share/sddm/themes"
THEME_NAME="sddm-astronaut-theme"
THEME_DIR="$THEME_BASE/$THEME_NAME"

if [ -d "$THEME_DIR" ]; then
  log "INFO Theme directory exists. Skipping clone."
else
  log "INFO Cloning Astronaut theme..."
  git clone --depth 1 https://github.com/Keyitdev/sddm-astronaut-theme.git /tmp/sddm-astronaut
  sudo mv /tmp/sddm-astronaut "$THEME_DIR"
  log "OK Theme installed to $THEME_DIR"
fi

# --- 3. CONFIGURE JAKE THE DOG PRESET ---
# The README says to edit metadata.desktop to change the ConfigFile
METADATA_FILE="$THEME_DIR/metadata.desktop"
TARGET_CONF="Themes/jake_the_dog.conf"

# Verify if the target config exists before switching (safety check)
if [ -f "$THEME_DIR/$TARGET_CONF" ]; then
  log "INFO Switching theme preset to Jake the Dog..."
  # Use sed to replace the ConfigFile line
  sudo sed -i "s|^ConfigFile=.*|ConfigFile=$TARGET_CONF|" "$METADATA_FILE"
  log "OK Theme set to $TARGET_CONF"
else
  log "WARN Jake the Dog config ($TARGET_CONF) not found. Keeping default."
  # List available themes in log for debugging
  log "Available themes: $(ls $THEME_DIR/Themes)"
fi

# --- 4. INSTALL FONTS ---
log "INFO Installing theme fonts..."
sudo cp -r "$THEME_DIR/Fonts/"* /usr/share/fonts/ || true
sudo fc-cache -f

# --- 5. CONFIGURE SDDM SYSTEM-WIDE ---
log "INFO Configuring /etc/sddm.conf..."

sudo tee /etc/sddm.conf >/dev/null <<EOF
[Theme]
Current=$THEME_NAME
EOF

# Virtual Keyboard
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/virtualkbd.conf >/dev/null <<EOF
[General]
InputMethod=qtvirtualkeyboard
EOF

# --- 6. ENABLE SERVICE ---
if [ ! -L /var/service/sddm ]; then
  log "INFO Linking SDDM service..."
  sudo ln -sf /etc/sv/sddm /var/service/sddm
  log "OK SDDM service enabled"
else
  log "INFO SDDM service already enabled"
fi

log "✅ sddm_astronaut.sh finished"
