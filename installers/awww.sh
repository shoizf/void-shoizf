#!/usr/bin/env bash
# installers/awww.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

# --- Check if we are running as the correct user ---
# This is a safety check. The parent script should already be running this as $TARGET_USER
if [ "$(whoami)" != "$TARGET_USER" ]; then
    echo "❌ [awww.sh] This script must be run as the target user ($TARGET_USER), not as $(whoami)."
    exit 1
fi

echo "Configuring AWWW for user: $TARGET_USER ($TARGET_USER_HOME)"

echo "Installing dependencies (rust via rustup, git, lz4, wayland headers, scdoc, jq, wget)..."
# We explicitly install 'gcc' to "protect" it from being removed.
# We add '-y' to auto-approve all prompts.
sudo xbps-install -Sy -y \
    gcc \
    git \
    liblz4-devel \
    pkg-config \
    wayland-devel \
    wayland-protocols \
    scdoc \
    jq \
    wget || echo "⚠️  Some dependencies may already be installed."

# Remove void linux rust to avoid conflict
echo "Removing system 'rust' package to install rustup..."
sudo xbps-remove -RF -y rust || true

# --- Install Rustup ---
# We no longer use 'sudo -u' because we are already the correct user.
if ! command -v rustup >/dev/null 2>&1; then
  echo "Rustup not found. Installing rustup and latest stable Rust..."
  # Run the installer with -y to auto-approve
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# --- FIX: Source the new environment ---
# This loads the new $PATH (with .cargo/bin) into the *current* script session.
echo "Sourcing Rust environment from $TARGET_USER_HOME/.cargo/env"
if [ -f "$TARGET_USER_HOME/.cargo/env" ]; then
    # Use '.' (the 'source' command)
    . "$TARGET_USER_HOME/.cargo/env"
else
    echo "❌ [awww.sh] Could not find cargo env file to source."
    exit 1
fi

# --- FIX: Validate in the *current* environment ---
# We no longer use 'sudo -u'. This check will now find 'rustc' in our new PATH.
if ! command -v rustc >/dev/null 2>&1; then
  echo "❌ rustc not found after rustup installation."
  exit 1
fi

RUST_VERSION=$(rustc --version)
echo "Using Rust: $RUST_VERSION"

# --- Build AWWW ---
BUILD_DIR="$TARGET_USER_HOME/builds"
AWWW_DIR="$BUILD_DIR/awww"
mkdir -p "$BUILD_DIR"
# 'chown' is not needed since we're already the correct user.

if [ -d "$AWWW_DIR" ]; then
  echo "Updating existing 'awww' repo..."
  if ! git -C "$AWWW_DIR" pull; then
    echo "Git pull failed, removing and recloning."
    rm -rf "$AWWW_DIR"
    git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR"
  fi
else
  echo "Cloning 'awww' repo..."
  git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR"
fi

echo "Contents of $AWWW_DIR after update or clone:"
ls -la "$AWWW_DIR"

CARGO_TOML_PATH="$AWWW_DIR/Cargo.toml"
if [ ! -f "$CARGO_TOML_PATH" ]; then
  echo "❌ Could not find Cargo.toml at $CARGO_TOML_PATH"
  exit 1
fi

echo "Building 'awww' in release mode..."
# No 'sudo -u' or 'bash -c' needed. We are the correct user
# and the environment is already sourced.
(cd "$AWWW_DIR" && cargo build --release)

echo "Installing 'awww' and 'awww-daemon' binaries to /usr/bin/..."
# We only use 'sudo' for the final copy to a system directory.
sudo cp "$AWWW_DIR/target/release/awww" /usr/bin/awww
sudo cp "$AWWW_DIR/target/release/awww-daemon" /usr/bin/awww-daemon

echo "Installing wallpaper cycler script..."
mkdir -p "$TARGET_USER_HOME/.local/bin"
cp "$REPO_ROOT/bin/wallpaper-cycler.sh" "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"
chmod +x "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"

echo "✅ 'awww' and wallpaper cycler script installed successfully."
