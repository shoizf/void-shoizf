#!/usr/bin/env bash
# installers/awww.sh
# Final robust version for clean install

set -euo pipefail # Stop on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

# --- Safety Check ---
if [ "$(whoami)" != "$TARGET_USER" ]; then
  echo "❌ [awww.sh] This script must be run as the target user ($TARGET_USER), not as $(whoami)."
  exit 1
fi

echo "--- [AWWW Installer] ---"
echo "Configuring for user: $TARGET_USER ($TARGET_USER_HOME)"

# --- 1. Install Build Dependencies ---
echo "Installing build dependencies (gcc, git, pkg-config, etc)..."
# We add '-y' to auto-approve all prompts.
sudo xbps-install -Sy -y \
  gcc \
  git \
  pkg-config \
  liblz4-devel \
  wayland-devel \
  wayland-protocols \
  scdoc \
  jq \
  wget || echo "⚠️  Some dependencies may already be installed."

# --- 2. Protect Build Tools ---
# This "protects" gcc and pkg-config from being removed.
echo "Protecting build tools from removal..."
sudo xbps-pkgdb -m manual gcc pkg-config

# --- 3. Remove Conflicting System Rust ---
echo "Removing system 'rust' package (if present) to install rustup..."
# We add '|| true' in case 'rust' isn't installed (which is fine)
sudo xbps-remove -RF -y rust || true

# --- 4. Install Rustup (as the user) ---
if ! command -v rustup >/dev/null 2>&1; then
  echo "Rustup not found. Installing rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# --- 5. Set the PATH for this script session ---
# This is the critical fix for 'rustc: command not found'
echo "Manually adding Cargo to PATH for this session..."
export PATH="$TARGET_USER_HOME/.cargo/bin:$PATH"

# --- 6. Validate Rustc ---
if ! command -v rustc >/dev/null 2>&1; then
  echo "❌ [awww.sh] rustc command not found even after PATH export."
  exit 1
fi
RUST_VERSION=$(rustc --version)
echo "Using Rust: $RUST_VERSION"

# --- 7. Clone/Update the 'awww' Repo ---
BUILD_DIR="$TARGET_USER_HOME/builds"
AWWW_DIR="$BUILD_DIR/awww"
mkdir -p "$BUILD_DIR"

if [ -d "$AWWW_DIR" ]; then
  echo "Updating existing 'awww' repo..."
  if ! git -C "$AWWW_DIR" pull; then
    echo "Git pull failed. Removing and re-cloning."
    rm -rf "$AWWW_DIR"
    git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR"
  fi
else
  echo "Cloning 'awww' repo..."
  git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR"
fi

# --- 8. Build 'awww' (Robustly) ---
echo "Building 'awww' in release mode..."
# We 'cd' into the directory, build, and then 'cd' back.
# If 'cargo build' fails, 'set -e' is guaranteed to stop the script.
cd "$AWWW_DIR"
if ! cargo build --release; then
  echo "❌ [awww.sh] Cargo build FAILED!"
  cd "$REPO_ROOT" # Go back before exiting
  exit 1
fi
# Go back to the original script directory
cd "$REPO_ROOT"
echo "✅ Build successful."

# --- 9. Install Binaries (as root) ---
echo "Installing 'awww' and 'awww-daemon' binaries to /usr/bin/..."
sudo cp "$AWWW_DIR/target/release/awww" /usr/bin/awww
sudo cp "$AWWW_DIR/target/release/awww-daemon" /usr/bin/awww-daemon

# --- 10. Install User Scripts ---
echo "Installing wallpaper cycler script..."
mkdir -p "$TARGET_USER_HOME/.local/bin"
cp "$REPO_ROOT/bin/wallpaper-cycler.sh" "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"
chmod +x "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"

# --- 11. Final Cleanup ---
echo "Cleaning up build directory..."
rm -rf "$BUILD_DIR"

echo "✅ 'awww' and wallpaper cycler script installed successfully."
