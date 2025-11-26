#!/usr/bin/env bash
# installers/dev-tools.sh — install LazyVim, tmux config, Obsidian

set -euo pipefail

# --- Logging setup ---
LOG_DIR="$HOME/.local/log/void-shoizf"
mkdir -p "$LOG_DIR"
SCRIPT_NAME="$(basename "$0" .sh)"

# Check if we're being run by the master installer
if [ -n "${VOID_SHOIZF_MASTER_LOG:-}" ]; then
	LOG_FILE="$VOID_SHOIZF_MASTER_LOG"
else
	# We are being run directly, create our own log
	TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
	LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
fi

log() {
	local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"
	echo "$msg" | tee -a "$LOG_FILE"
}
# --- End Logging setup ---

log "▶ dev-tools.sh starting"

if [ "$EUID" -eq 0 ]; then
	log "ERROR Do not run dev-tools.sh as root. Exiting."
	exit 1
fi

# LazyVim
log "INFO Installing LazyVim starter"
rm -rf "$HOME/.config/nvim" "$HOME/.local/share/nvim" || true
if git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"; then
	log "OK LazyVim cloned"
else
	log "WARN LazyVim clone failed"
fi

# tmux config
log "INFO Installing Oh My Tmux!"
rm -rf "$HOME/.tmux" "$HOME/.tmux.conf" || true
if git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux"; then
	ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
	cp "$HOME/.tmux/.tmux.conf.local" "$HOME/" || true

	# --- AUTOMATED CONFIGURATION PATCHING ---
	CONF_LOCAL="$HOME/.tmux.conf.local"

	log "INFO Patching .tmux.conf.local for Wayland clipboard support..."

	if [ -f "$CONF_LOCAL" ]; then
		# 1. Enable OS clipboard integration (Copy: Tmux -> OS)
		#    This tells oh-my-tmux to attempt using external tools.
		sed -i 's/^# tmux_conf_copy_to_os_clipboard=true/tmux_conf_copy_to_os_clipboard=true/' "$CONF_LOCAL"

		# 2. Append Wayland specific glue (Paste: OS -> Tmux)
		#    This forces wl-copy/paste specifically for your Niri environment.
		cat <<EOF >>"$CONF_LOCAL"

# -- Shoizf Wayland Clipboard Integration --
set -g set-clipboard on
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy"
bind p run "wl-paste --no-newline | tmux load-buffer - ; tmux paste-buffer"
set -g update-environment "DISPLAY SSH_ASKPASS SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION WINDOWID XAUTHORITY WAYLAND_DISPLAY SWAYSOCK XDG_SESSION_TYPE"
EOF
		log "OK tmux config patched."
	else
		log "WARN .tmux.conf.local not found, skipping patch."
	fi
	# ----------------------------------------

	log "OK tmux config installed"
else
	log "WARN tmux clone failed"
fi

# Obsidian AppImage (best-effort)
log "INFO Installing Obsidian AppImage (best-effort)"
# use the existing logic but don't fail the script on network errors

fetch_latest_appimage_url() {
	# minimal fallback extractor
	curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest 2>/dev/null |
		grep -oE 'https://[^"]+\.AppImage' | head -n1 || true
}

LATEST_URL="$(fetch_latest_appimage_url)"
if [ -n "$LATEST_URL" ]; then
	TMPFILE="$(mktemp /tmp/obsidian.XXXXXX)"
	if curl -fL -s -o "$TMPFILE" "$LATEST_URL"; then
		mkdir -p "$HOME/.local/bin"
		mv "$TMPFILE" "$HOME/.local/bin/obsidian.AppImage"
		chmod +x "$HOME/.local/bin/obsidian.AppImage"
		ln -sf "$HOME/.local/bin/obsidian.AppImage" "$HOME/.local/bin/obsidian"
		log "OK Obsidian AppImage installed"
	else
		log "WARN Failed to download Obsidian AppImage"
	fi
else
	log "WARN Could not determine Obsidian download URL"
fi

log "✅ dev-tools.sh finished"
