#!/usr/bin/env bash
# installers/sddm_astronaut.sh — Install SDDM Astronaut theme + interactive theme selector
# ROOT-SCRIPT — must be run as root (no sudo inside)
#
#  void-shoizf Script Version
# ------------------------------------------------------
#  Name:    sddm_astronaut.sh
#  Version: 1.0.0
#  Updated: 2025-12-09
#  Purpose: Root installer for sddm-astronaut-theme. Clones theme into a temp dir,
#           installs fonts, writes sddm config & virtualkbd config, links service.
# ------------------------------------------------------

set -euo pipefail

# ---------------------------
# 0. SANITY: must be root
# ---------------------------
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: this script must be run as root." >&2
  exit 1
fi

# ---------------------------
# 1. Metadata / logging
# ---------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="/var/log/void-shoizf"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"

log() { local m="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"; echo "$m" >>"$LOG_FILE"; }
info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
error() { log "ERROR $*"; exit 1; }
ok()    { log "OK    $*"; }
pp()    { echo -e "$*"; }

pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"

# Credit (not ownership)
info "Theme credit: Keyitdev — sddm-astronaut-theme (we ship/install their theme; script owned by void-shoizf)"

# ---------------------------
# 2. Variables & paths
# ---------------------------
THEME_REPO="https://github.com/Keyitdev/sddm-astronaut-theme.git"
THEME_NAME="sddm-astronaut-theme"
THEME_INSTALL_DIR="/usr/share/sddm/themes/${THEME_NAME}"
TEMP_DIR="$(mktemp -d /tmp/${THEME_NAME}.XXXXXX)"
trap 'rc=$?; rm -rf "$TEMP_DIR" || true; log "Cleaned tempdir $TEMP_DIR"; exit $rc' EXIT

# timeout countdown defaults
COUNTDOWN_DEFAULT=15
DEFAULT_PRESET="jake_the_dog.conf"    # name inside Themes/

# ---------------------------
# 3. Clone (user-owned temp; as root it's still fine)
# ---------------------------
info "Cloning theme into tempdir: $TEMP_DIR"
if ! command -v git >/dev/null 2>&1; then
  error "git not found in PATH — please install git first (packages.sh)."
fi

# ensure empty temp dir
rm -rf "$TEMP_DIR" && mkdir -p "$TEMP_DIR"
if ! git clone --depth 1 "$THEME_REPO" "$TEMP_DIR" >>"$LOG_FILE" 2>&1; then
  error "Failed to clone $THEME_REPO (see $LOG_FILE)"
fi
ok "Cloned theme to $TEMP_DIR"

# remove .git to avoid shipping VCS metadata
rm -rf "$TEMP_DIR/.git" || true

# ---------------------------
# 4. Gather theme options
# ---------------------------
THEMES_DIR="$TEMP_DIR/Themes"
if [ ! -d "$THEMES_DIR" ]; then
  warn "Cloned theme does not contain Themes/ directory — continuing but selection may be limited"
fi

# produce alphabetical list of theme files (basename)
mapfile -t THEME_FILES < <(find "$THEMES_DIR" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' 2>/dev/null | sort -f)
# fallback: if default not present and list empty, rely on metadata or one-off
if [ ${#THEME_FILES[@]} -eq 0 ]; then
  warn "No theme confs found in $THEMES_DIR; installer will still copy files but selection not possible"
fi

# ensure default exists in list; otherwise pick first
if ! printf '%s\n' "${THEME_FILES[@]}" | grep -qx "$DEFAULT_PRESET"; then
  if [ ${#THEME_FILES[@]} -gt 0 ]; then
    DEFAULT_PRESET="${THEME_FILES[0]}"
    warn "Default preset not found; falling back to ${DEFAULT_PRESET}"
  else
    DEFAULT_PRESET=""
  fi
fi

# ---------------------------
# 5. Interactive selection with countdown (root-mode)
# ---------------------------
choose_preset_interactive() {
  # If no themes, return empty (caller will handle)
  if [ ${#THEME_FILES[@]} -eq 0 ]; then
    echo ""
    return
  fi

  pp ""
  pp "Available themes:"
  idx=1
  for t in "${THEME_FILES[@]}"; do
    printf "  %2d) %s\n" "$idx" "$t"
    idx=$((idx+1))
  done
  pp ""
  pp "Default: $DEFAULT_PRESET"
  pp "Type the theme number and press ENTER to choose, or wait ${COUNTDOWN_DEFAULT}s for default."
  pp "Controls: p = pause, r = resume, ENTER = select default"
  pp ""

  # interactive countdown loop — listens for single-char keys
  timeout=$COUNTDOWN_DEFAULT
  paused=0
  sel=""

  # use stty to configure input behavior
  old_stty="$(stty -g || true)"
  stty -icanon -echo min 0 time 0

  while [ "$timeout" -ge 0 ]; do
    # show prompt
    printf "\rSelecting default in %2ds... (press number + ENTER to pick; p=pause r=resume) " "$timeout" >&2

    # non-blocking read: read up to 64 chars or until newline
    IFS= read -r -t 1 -n 64 input 2>/dev/null || input=""
    # if input contains newline, separate the token before newline
    if [ -n "$input" ]; then
      # normalize input (strip whitespace)
      token="$(printf '%s' "$input" | tr -d '\r\n\t ')"
      case "$token" in
        p|P)
          paused=1
          pp "\n[paused] countdown paused. press 'r' to resume or enter number to select."
          ;;
        r|R)
          if [ "$paused" -eq 1 ]; then
            paused=0
            pp "\n[resumed] countdown resumed."
          fi
          ;;
        '' )
          # ignore empty
          ;;
        *)
          # if token is digits, treat as immediate selection if followed by ENTER
          if printf '%s' "$token" | grep -qE '^[0-9]+$'; then
            sel="$token"
            # consume remaining input until newline if any
            # break to selection branch
            break
          else
            pp "\nInvalid input: '$token' (use number, p, r)"
          fi
          ;;
      esac
    fi

    # decrement timeout only when not paused
    if [ "$paused" -eq 0 ]; then
      timeout=$((timeout-1))
    fi

    # if timeout reached zero, break
    if [ "$timeout" -lt 0 ]; then break; fi
  done

  # restore stty
  stty "$old_stty" || true
  printf "\n" >&2

  if [ -n "$sel" ]; then
    # sel is a numeric index
    if [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le "${#THEME_FILES[@]}" ] 2>/dev/null; then
      echo "${THEME_FILES[$((sel-1))]}"
      return
    else
      warn "Selection number out of range; falling back to default"
      echo "$DEFAULT_PRESET"
      return
    fi
  fi

  # if no explicit selection, choose default
  echo "$DEFAULT_PRESET"
}

SELECTED_PRESET="$(choose_preset_interactive)"

if [ -z "${SELECTED_PRESET:-}" ]; then
  warn "No preset selected or available — installer will copy theme but not set a specific preset."
else
  info "User selected preset: $SELECTED_PRESET"
fi

# ---------------------------
# 6. Install theme into system directory
# ---------------------------
info "Installing theme into $THEME_INSTALL_DIR"

# remove old theme dir (if exists) safely
if [ -d "$THEME_INSTALL_DIR" ]; then
  info "Removing existing theme at $THEME_INSTALL_DIR"
  rm -rf "$THEME_INSTALL_DIR" >>"$LOG_FILE" 2>&1 || warn "Failed to remove old theme dir (check permissions)"
fi

# copy (preserve structure)
cp -a "$TEMP_DIR" "$THEME_INSTALL_DIR" >>"$LOG_FILE" 2>&1 || error "Failed to copy theme to $THEME_INSTALL_DIR"
ok "Theme copied to $THEME_INSTALL_DIR"

# ---------------------------
# 7. Fonts: copy theme fonts to system fonts
# ---------------------------
if [ -d "$THEME_INSTALL_DIR/Fonts" ]; then
  info "Installing theme fonts to /usr/share/fonts/"
  cp -a "$THEME_INSTALL_DIR/Fonts/"* /usr/share/fonts/ >>"$LOG_FILE" 2>&1 || warn "Failed copying fonts"
  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 || warn "fc-cache run failed"
  fi
  ok "Fonts installed (if any)"
else
  info "Theme contains no Fonts/ directory — skipping fonts install"
fi

# ---------------------------
# 8. Apply preset: update metadata.desktop if preset chosen
# ---------------------------
METADATA="$THEME_INSTALL_DIR/metadata.desktop"
if [ -n "${SELECTED_PRESET:-}" ] && [ -f "$METADATA" ]; then
  info "Applying preset $SELECTED_PRESET via metadata.desktop"
  # Write ConfigFile to the selected preset (safe sed)
  # Ensure the path is Themes/<preset>
  sed -i "s|^ConfigFile=.*|ConfigFile=Themes/${SELECTED_PRESET}|" "$METADATA" >>"$LOG_FILE" 2>&1 || warn "Could not set ConfigFile in metadata.desktop"
  ok "Preset applied in metadata.desktop"
fi

# ---------------------------
# 9. Write /etc/sddm.conf & virtualkbd conf
# ---------------------------
info "Writing /etc/sddm.conf"
cat >/etc/sddm.conf <<EOF
[Theme]
Current=${THEME_NAME}
ConfigFile=Themes/${SELECTED_PRESET:-$DEFAULT_PRESET}
EOF

mkdir -p /etc/sddm.conf.d
cat >/etc/sddm.conf.d/virtualkbd.conf <<'EOF'
[General]
InputMethod=qtvirtualkeyboard
EOF

ok "/etc/sddm.conf and virtualkbd.conf written"

# ---------------------------
# 10. Enable SDDM service (link; do not restart)
# ---------------------------
if [ ! -L /var/service/sddm ]; then
  ln -sf /etc/sv/sddm /var/service/
  ok "SDDM service link created (/var/service/sddm)"
else
  info "SDDM service link already exists"
fi

# ---------------------------
# 11. Finalize & cleanup (trap will remove tempdir)
# ---------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ SDDM Astronaut theme installed. Preset: ${SELECTED_PRESET:-(none)}"
exit 0
