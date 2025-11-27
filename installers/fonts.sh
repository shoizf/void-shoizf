#!/usr/bin/env bash
# installers/fonts.sh — Install fonts (Read from Repo / Download to Cache)
# USER-SCRIPT — never run as root; writes to user locations only.

set -euo pipefail

# ------------------------------------------------------
# 1. NORMALIZE CONTEXT
# ------------------------------------------------------
SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Prefer TARGET_* provided by install.sh
if [ -n "${TARGET_USER:-}" ] && [ -n "${TARGET_HOME:-}" ]; then
  TARGET_USER="${TARGET_USER}"
  TARGET_HOME="${TARGET_HOME}"
else
  TARGET_USER="$(logname 2>/dev/null || whoami)"
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || echo "$HOME")"
fi

# Master orchestrator log vs standalone log
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
  LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
  MASTER_MODE=true
else
  LOG_DIR="$TARGET_HOME/.local/log/void-shoizf"
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
  if [ "$QUIET_MODE" = false ] && [ "$MASTER_MODE" = false ]; then
    echo "$msg"
  fi
}
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
error() { log "ERROR $*"; }
ok() { log "OK    $*"; }
pp() { echo -e "$*"; } # minimal allowed terminal output

# ------------------------------------------------------
# 3. STARTUP & VALIDATION
# ------------------------------------------------------
pp "▶ $SCRIPT_NAME"
log "▶ Starting installer: $SCRIPT_NAME"
log "Context: TARGET_USER=${TARGET_USER}, TARGET_HOME=${TARGET_HOME}, MASTER_MODE=${MASTER_MODE}"

if [ "$EUID" -eq 0 ]; then
  error "Do NOT run fonts.sh as root"
  pp "❌ Must run as USER"
  exit 1
fi

# ------------------------------------------------------
# 4. PATHS
# ------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEST_DIR="${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/fonts"
DOWNLOAD_CACHE="${XDG_CACHE_HOME:-$TARGET_HOME/.cache}/void-shoizf/fonts"
REPO_ASSETS="$REPO_ROOT/assets/fonts"

mkdir -p "$DEST_DIR"
mkdir -p "$DOWNLOAD_CACHE"

# ------------------------------------------------------
# 5. INSTALL BUNDLED (REPO) FONTS (READ-ONLY)
# ------------------------------------------------------
if [ -d "$REPO_ASSETS" ]; then
  info "Installing bundled fonts from repo: $REPO_ASSETS"
  while IFS= read -r -d '' f; do
    fname="$(basename "$f")"
    dst="$DEST_DIR/$fname"
    if [ ! -f "$dst" ]; then
      cp -p "$f" "$dst"
      chmod 644 "$dst"
      chown "$TARGET_USER":"$TARGET_USER" "$dst" 2>/dev/null || true
      log "INSTALLED bundled font: $fname"
    else
      log "SKIP bundled font (exists): $fname"
    fi
  done < <(find "$REPO_ASSETS" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -print0)
else
  warn "Repo assets folder not found ($REPO_ASSETS). Skipping bundled fonts."
fi

# ------------------------------------------------------
# 6. EXTERNAL FONTS (CACHE) — JetBrains Mono (example)
# ------------------------------------------------------
JB_DIR="$DOWNLOAD_CACHE/JetBrainsMono"
JB_ZIP="$JB_DIR/archive.zip"
# pinned example release; adjust as needed
JB_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"

if [ ! -d "$JB_DIR" ]; then
  info "JetBrains Mono not found in cache. Will attempt download into $JB_DIR"
  mkdir -p "$JB_DIR"
  if command -v wget >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
    info "Downloading JetBrains Mono..."
    if wget -q -O "$JB_ZIP" "$JB_URL" >>"$LOG_FILE" 2>&1; then
      TMP_EXTRACT_DIR="$(mktemp -d "${JB_DIR}/extract.XXXX")"
      if unzip -o -q "$JB_ZIP" -d "$TMP_EXTRACT_DIR" >>"$LOG_FILE" 2>&1; then
        # move font files from extracted tree into JB_DIR
        find "$TMP_EXTRACT_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec mv -v {} "$JB_DIR/" \; >>"$LOG_FILE" 2>&1 || true
        rm -rf "$TMP_EXTRACT_DIR"
        rm -f "$JB_ZIP"
        ok "JetBrains Mono downloaded & extracted to cache"
      else
        error "Failed to extract JetBrains Mono archive"
        rm -rf "$TMP_EXTRACT_DIR" "$JB_ZIP"
        rm -rf "$JB_DIR"
      fi
    else
      error "Failed to download JetBrains Mono"
      rm -rf "$JB_DIR"
    fi
  else
    warn "Missing wget/unzip; skipping JetBrains Mono download. Install them system-wide if needed."
  fi
else
  info "JetBrains Mono cache exists: $JB_DIR"
fi

# Install from cache if present
if [ -d "$JB_DIR" ]; then
  info "Installing cached fonts from $JB_DIR → $DEST_DIR"
  while IFS= read -r -d '' f; do
    fname="$(basename "$f")"
    dst="$DEST_DIR/$fname"
    if [ ! -f "$dst" ]; then
      cp -p "$f" "$dst"
      chmod 644 "$dst"
      chown "$TARGET_USER":"$TARGET_USER" "$dst" 2>/dev/null || true
      log "INSTALLED cached font: $fname"
    else
      log "SKIP cached font (exists): $fname"
    fi
  done < <(find "$JB_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -print0)
fi

# ------------------------------------------------------
# 7. REFRESH FONT CACHE
# ------------------------------------------------------
info "Refreshing font cache for $DEST_DIR"
if fc-cache -f "$DEST_DIR" >>"$LOG_FILE" 2>&1; then
  ok "Font cache refreshed"
else
  warn "fc-cache returned non-zero (see log)"
fi

# ------------------------------------------------------
# 8. FINISH
# ------------------------------------------------------
log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
