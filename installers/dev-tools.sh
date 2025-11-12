#!/usr/bin/env bash
# installers/dev-tools.sh
# shoizf dev-tools installer
# Installs LazyVim, Oh My Tmux!, and latest stable Obsidian AppImage + SVG icon + .desktop
# Default: system-wide (/usr/bin, /usr/share) and uses sudo (assumed available).
# Flex: --user for per-user install (no sudo), --no-sudo to avoid sudo prefix, --clean to wipe previous installs.
# Maintainer: shoizf

set -euo pipefail
IFS=$'\n\t'

PROGNAME="$(basename "$0")"
LOG_DIR="${HOME}/.local/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/dev-tools_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

info() { printf "[%s] [INFO] %s\n" "$PROGNAME" "$*"; }
warn() { printf "[%s] [WARN] %s\n" "$PROGNAME" "$*"; }
error() {
  printf "[%s] [ERROR] %s\n" "$PROGNAME" "$*"
  exit 1
}

# Defaults (developer-chosen)
INSTALL_SYSTEM=true # if true, install system-wide paths (requires sudo)
SUDO_CMD="sudo"     # prefix for privileged ops; set empty if --no-sudo or --user
INSTALL_BIN="/usr/bin"
INSTALL_ICON_DIR="/usr/share/icons/hicolor/scalable/apps"
DESKTOP_DIR="/usr/share/applications"

# Per-user fallback (if --user)
USER_BIN="${HOME}/.local/bin"
USER_ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
USER_DESKTOP_DIR="${HOME}/.local/share/applications"

# CLI flags
CLEAN=false
NO_SUDO=false
USER_INSTALL=false
ARCH="$(uname -m)"

usage() {
  cat <<EOF
$PROGNAME — Install LazyVim, Oh My Tmux!, and Obsidian AppImage.

Usage: $PROGNAME [options]

Options:
  --user        Install to per-user locations (~/.local) (no sudo)
  --no-sudo     Don't prefix commands with sudo (assumes you are root)
  --clean       Remove prior installed artifacts before installing
  --help        Show this help
EOF
  exit 0
}

# Parse args
while [ "${#:-}" -gt 0 ]; do
  case "${1:-}" in
  --user)
    USER_INSTALL=true
    INSTALL_SYSTEM=false
    SUDO_CMD=""
    shift
    ;;
  --no-sudo)
    NO_SUDO=true
    SUDO_CMD=""
    shift
    ;;
  --clean)
    CLEAN=true
    shift
    ;;
  --help) usage ;;
  --)
    shift
    break
    ;;
  -*)
    echo "Unknown option: $1" >&2
    usage
    ;;
  *) break ;;
  esac
done

# set paths based on install mode
if [ "$USER_INSTALL" = true ]; then
  INSTALL_BIN="$USER_BIN"
  INSTALL_ICON_DIR="$USER_ICON_DIR"
  DESKTOP_DIR="$USER_DESKTOP_DIR"
  [ -z "$SUDO_CMD" ] || SUDO_CMD=""
fi

# helper to run a privileged command if needed
run_priv() {
  if [ -n "$SUDO_CMD" ]; then
    $SUDO_CMD "$@"
  else
    "$@"
  fi
}

# Clean previous installs (if requested)
clean_previous() {
  info "Cleaning previous dev-tools artifacts..."
  if [ "$USER_INSTALL" = true ]; then
    rm -f "$HOME/.local/bin/obsidian" "$HOME/.local/bin/obsidian.AppImage" 2>/dev/null || true
    rm -f "$HOME/.local/share/applications/obsidian.desktop" 2>/dev/null || true
    rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/obsidian.svg" 2>/dev/null || true
  else
    run_priv rm -f /usr/bin/obsidian /usr/bin/obsidian.AppImage 2>/dev/null || true
    run_priv rm -f /usr/share/applications/obsidian.desktop 2>/dev/null || true
    run_priv rm -f /usr/share/icons/hicolor/scalable/apps/obsidian.svg 2>/dev/null || true
  fi
}

# 1) LazyVim install
install_lazyvim() {
  info "Installing LazyVim (Neovim + starter config)..."
  # Ensure git present
  if ! command -v git >/dev/null 2>&1; then
    info "git not found — installing git via xbps"
    run_priv xbps-install -Sy git
  fi

  # remove and re-clone (force reinstall per requirements)
  rm -rf "$HOME/.config/nvim" "$HOME/.local/share/nvim" || true
  if git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"; then
    info "LazyVim starter cloned to ~/.config/nvim"
  else
    warn "Failed to clone LazyVim starter; continuing"
  fi

  # Attempt headless lazy sync if nvim exists (optional)
  if command -v nvim >/dev/null 2>&1; then
    nvim --headless "+Lazy! sync" +qa || warn "LazyVim: headless sync failed or skipped"
  else
    warn "nvim not installed; skip plugin sync (user can run later)"
  fi
}

# 2) Oh My Tmux install
install_tmux() {
  info "Installing Oh My Tmux! configuration..."
  rm -rf "$HOME/.tmux" "$HOME/.tmux.conf" "$HOME/.tmux.conf.local" || true
  if git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux"; then
    ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
    cp "$HOME/.tmux/.tmux.conf.local" "$HOME/" || true
    info "Oh My Tmux! installed at ~/.tmux"
  else
    warn "Failed to clone Oh My Tmux! repo; continuing"
  fi
}

# 3) Obsidian AppImage download (latest stable)
fetch_latest_appimage_url() {
  info "Discovering latest Obsidian AppImage release via GitHub API..."
  # Try jq if available (robust)
  if command -v jq >/dev/null 2>&1; then
    # prefer non-arm64 by default on x86; if arch is arm64 and only arm asset exists, pick it
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
      # prefer arm64
      curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
        jq -r '.assets[] | select(.name | test("AppImage$")) | .browser_download_url' |
        grep -i -m1 -E 'arm64|aarch64' ||
        curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
        jq -r '.assets[] | select(.name | test("AppImage$")) | .browser_download_url' |
          head -n1
    else
      # prefer non-arm
      curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
        jq -r '.assets[] | select(.name | test("AppImage$")) | .browser_download_url' |
        grep -i -m1 -E -v 'arm64|aarch64' ||
        curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
        jq -r '.assets[] | select(.name | test("AppImage$")) | .browser_download_url' |
          head -n1
    fi
  else
    # Fallback to grep-parsing (works in most cases)
    # First try to get x86 (non-arm) AppImage
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
      curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
        grep -oE 'https://[^"]+Obsidian-[0-9.]+.*-arm64\.AppImage' |
        head -n1 ||
        curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
        grep -oE 'https://[^"]+Obsidian-[0-9.]+.*AppImage' | head -n1
    else
      curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
        grep -oE 'https://[^"]+Obsidian-[0-9.]+\.AppImage' |
        grep -v 'arm64' | head -n1
    fi
  fi
}

install_obsidian() {
  info "Installing latest Obsidian AppImage (forced reinstall)..."
  LATEST_URL="$(fetch_latest_appimage_url || true)"

  if [ -z "${LATEST_URL:-}" ]; then
    error "Could not detect latest Obsidian AppImage URL (check network/GitHub API)."
  fi

  info "Latest AppImage URL: $LATEST_URL"

  # ensure install dirs
  if [ "$USER_INSTALL" = true ]; then
    mkdir -p "$INSTALL_BIN"
    mkdir -p "$INSTALL_ICON_DIR"
    mkdir -p "$DESKTOP_DIR"
  else
    run_priv mkdir -p "$INSTALL_BIN"
    run_priv mkdir -p "$INSTALL_ICON_DIR"
    run_priv mkdir -p "$DESKTOP_DIR"
  fi

  # download AppImage
  TMPFILE="$(mktemp /tmp/obsidian.XXXXXX)"
  curl -fL -o "$TMPFILE" "$LATEST_URL" || {
    rm -f "$TMPFILE"
    error "Failed downloading AppImage"
  }

  # remove and install
  if [ "$USER_INSTALL" = true ]; then
    rm -f "$INSTALL_BIN/obsidian" "$INSTALL_BIN/obsidian.AppImage" || true
    mv "$TMPFILE" "$INSTALL_BIN/obsidian.AppImage"
    chmod +x "$INSTALL_BIN/obsidian.AppImage"
    ln -sf "$INSTALL_BIN/obsidian.AppImage" "$INSTALL_BIN/obsidian"
  else
    run_priv rm -f /usr/bin/obsidian /usr/bin/obsidian.AppImage 2>/dev/null || true
    run_priv mv "$TMPFILE" "$INSTALL_BIN/obsidian.AppImage"
    run_priv chmod +x "$INSTALL_BIN/obsidian.AppImage"
    run_priv ln -sf "$INSTALL_BIN/obsidian.AppImage" "$INSTALL_BIN/obsidian"
  fi

  info "Obsidian AppImage installed to: $INSTALL_BIN/obsidian.AppImage"
}

install_icon_and_desktop() {
  info "Installing SVG icon and .desktop entry..."

  ICON_URL="https://obsidian.md/favicon.svg"
  if [ "$USER_INSTALL" = true ]; then
    mkdir -p "$INSTALL_ICON_DIR"
    curl -fsSL "$ICON_URL" -o "$INSTALL_ICON_DIR/obsidian.svg" || warn "Failed to fetch icon"
    # desktop
    mkdir -p "$DESKTOP_DIR"
    cat >"$DESKTOP_DIR/obsidian.desktop" <<EOF
[Desktop Entry]
Name=Obsidian
Exec=$INSTALL_BIN/obsidian %U
Icon=obsidian
Type=Application
Categories=Office;Notes;Utility;
MimeType=text/markdown;
StartupNotify=true
EOF
  else
    run_priv mkdir -p "$INSTALL_ICON_DIR"
    run_priv curl -fsSL "$ICON_URL" -o "$INSTALL_ICON_DIR/obsidian.svg" || warn "Failed to fetch icon (system)"
    # system desktop
    run_priv tee "$DESKTOP_DIR/obsidian.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=Obsidian
Exec=$INSTALL_BIN/obsidian %U
Icon=obsidian
Type=Application
Categories=Office;Notes;Utility;
MimeType=text/markdown;
StartupNotify=true
EOF
    # refresh database if tool present
    if command -v update-desktop-database >/dev/null 2>&1; then
      run_priv update-desktop-database >/dev/null 2>&1 || true
    fi
  fi

  info ".desktop entry written to: $DESKTOP_DIR/obsidian.desktop"
}

# main flow
info "Starting dev-tools installation. Logging -> $LOG_FILE"
info "Install mode: $([ "$USER_INSTALL" = true ] && echo "user" || echo "system")"

if [ "$CLEAN" = true ]; then
  clean_previous
fi

install_lazyvim
install_tmux
install_obsidian
install_icon_and_desktop

info "All tasks complete."
info "Log file: $LOG_FILE"
info "You can run 'obsidian' to start Obsidian (or find it in your app menu)."

# End of script
