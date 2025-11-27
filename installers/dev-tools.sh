#!/usr/bin/env bash
# installers/dev-tools.sh — install LazyVim, tmux presets, Obsidian
# USER-SCRIPT — must NOT be run as root.

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
# 2. LOGGING
# ------------------------------------------------------

log() {
  local m="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
  echo "$m" >>"$LOG_FILE"
  if [ "$QUIET_MODE" = false ] && [ "$MASTER_MODE" = false ]; then echo "$m"; fi
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
log "▶ Starting installer: $SCRIPT_NAME (User Mode)"
log "Context: TARGET_USER=${TARGET_USER}, TARGET_HOME=${TARGET_HOME}, MASTER_MODE=${MASTER_MODE}"

if [ "$EUID" -eq 0 ]; then
  error "dev-tools.sh must NOT run as root"
  pp "❌ ERROR: run as normal user"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ------------------------------------------------------
# 4. INSTALL LAZYVIM (IDEMPOTENT)
# ------------------------------------------------------

NVIM_DIR="$TARGET_HOME/.config/nvim"

info "Installing LazyVim…"

if [ -d "$NVIM_DIR" ]; then
  BACKUP="${NVIM_DIR}.bak-${TIMESTAMP}"
  info "Backing up existing nvim → $BACKUP"
  mv "$NVIM_DIR" "$BACKUP"
fi

if git clone --depth=1 https://github.com/LazyVim/starter "$NVIM_DIR" >>"$LOG_FILE" 2>&1; then
  ok "LazyVim installed"
else
  warn "LazyVim clone failed — check network"
fi

chown -R "$TARGET_USER":"$TARGET_USER" "$NVIM_DIR" 2>/dev/null || true

# ------------------------------------------------------
# 5. INSTALL OH MY TMUX + PATCH (IDEMPOTENT)
# ------------------------------------------------------

info "Installing Oh My Tmux!"

TMUX_DIR="$TARGET_HOME/.tmux"
CONF_MAIN="$TARGET_HOME/.tmux.conf"
CONF_LOCAL="$TARGET_HOME/.tmux.conf.local"

rm -rf "$TMUX_DIR" "$CONF_MAIN" >>"$LOG_FILE" 2>&1 || true

if git clone https://github.com/gpakosz/.tmux.git "$TMUX_DIR" >>"$LOG_FILE" 2>&1; then
  ln -sf "$TMUX_DIR/.tmux.conf" "$CONF_MAIN"
  cp "$TMUX_DIR/.tmux.conf.local" "$CONF_LOCAL" >>"$LOG_FILE" 2>&1 || true

  if ! grep -q "Shoizf Wayland Clipboard Integration" "$CONF_LOCAL" 2>/dev/null; then
    info "Applying tmux Wayland clipboard patch…"
    cat <<'EOF' >>"$CONF_LOCAL"

# -- Shoizf Wayland Clipboard Integration --
set -g set-clipboard on
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy"
bind p run "wl-paste --no-newline | tmux load-buffer - ; tmux paste-buffer"
set -g update-environment "DISPLAY SSH_ASKPASS SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION WINDOWID XAUTHORITY WAYLAND_DISPLAY SWAYSOCK XDG_SESSION_TYPE"
EOF
    ok "tmux patch applied"
  else
    info "tmux Wayland patch already present"
  fi

  ok "tmux installed"
else
  warn "Oh My Tmux clone failed"
fi

chown -R "$TARGET_USER":"$TARGET_USER" "$TMUX_DIR" "$CONF_MAIN" "$CONF_LOCAL" 2>/dev/null || true

# ------------------------------------------------------
# 6. INSTALL / UPDATE OBSIDIAN APPIMAGE (IDEMPOTENT)
# ------------------------------------------------------

APP_BIN="$TARGET_HOME/.local/bin/obsidian.AppImage"
APP_LINK="$TARGET_HOME/.local/bin/obsidian"
mkdir -p "$TARGET_HOME/.local/bin"

info "Installing/Updating Obsidian…"

fetch_latest() {
  curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
    grep -oE 'https://[^"]+\.AppImage' | head -n1 || true
}

URL="$(fetch_latest)"

if [ -z "$URL" ]; then
  warn "Could not fetch Obsidian URL (GitHub API issue or rate-limit)"
else
  TMP="$(mktemp)"
  if curl -fsSL -o "$TMP" "$URL" >>"$LOG_FILE" 2>&1; then

    NEW_HASH="$(sha256sum "$TMP" | awk '{print $1}')"
    OLD_HASH=""
    [ -f "$APP_BIN" ] && OLD_HASH="$(sha256sum "$APP_BIN" | awk '{print $1}')"

    if [ "$NEW_HASH" = "$OLD_HASH" ]; then
      info "Obsidian already up to date"
      rm -f "$TMP"
    else
      mv "$TMP" "$APP_BIN"
      chmod +x "$APP_BIN"
      ln -sf "$APP_BIN" "$APP_LINK"
      ok "Obsidian installed/updated"
    fi
  else
    warn "Download failed for Obsidian"
    rm -f "$TMP"
  fi
fi

chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.local/bin" 2>/dev/null || true

# ------------------------------------------------------
# 7. END
# ------------------------------------------------------

log "✔ Finished installer: $SCRIPT_NAME"
pp "✔ $SCRIPT_NAME done"
exit 0
