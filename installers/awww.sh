#!/usr/bin/env bash
# installers/awww.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

echo "Configuring AWWW for user: $TARGET_USER ($TARGET_USER_HOME)"

echo "Installing dependencies (rust via rustup, git, lz4, wayland headers, scdoc, jq, wget)..."
sudo xbps-install -Sy git liblz4-devel wayland-devel wayland-protocols scdoc jq wget || echo "⚠️ Some dependencies may already be installed."

# Remove void linux rust to avoid conflict
sudo xbps-remove -RF rust || true

# Install or update rustup for managed rust toolchain
if ! sudo -u "$TARGET_USER" command -v rustup >/dev/null 2>&1; then
  echo "Rustup not found. Installing rustup and latest stable Rust..."
  sudo -u "$TARGET_USER" curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sudo -u "$TARGET_USER" sh -s -- -y
fi

# Source cargo environment for rust and cargo commands
export CARGO_HOME="$TARGET_USER_HOME/.cargo"
export RUSTUP_HOME="$TARGET_USER_HOME/.rustup"
export PATH="$CARGO_HOME/bin:$PATH"

# Validate rustc presence and version
if ! command -v rustc >/dev/null 2>&1; then
  echo "❌ rustc not found after rustup installation."
  exit 1
fi

RUST_VERSION=$(rustc --version)
echo "Using Rust: $RUST_VERSION"

BUILD_DIR="$TARGET_USER_HOME/builds"
AWWW_DIR="$BUILD_DIR/awww"
sudo -u "$TARGET_USER" mkdir -p "$BUILD_DIR"
sudo chown -R "$TARGET_USER:$TARGET_USER" "$BUILD_DIR"

if [ -d "$AWWW_DIR" ]; then
  echo "Updating existing 'awww' repo..."
  sudo -u "$TARGET_USER" ls -la "$AWWW_DIR"
  if ! sudo -u "$TARGET_USER" git -C "$AWWW_DIR" pull; then
    echo "Git pull failed, removing and recloning."
    sudo -u "$TARGET_USER" rm -rf "$AWWW_DIR"
    sudo -u "$TARGET_USER" git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR"
  fi
else
  echo "Cloning 'awww' repo..."
  sudo -u "$TARGET_USER" git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR"
fi

echo "Contents of $AWWW_DIR after update or clone:"
sudo -u "$TARGET_USER" ls -la "$AWWW_DIR"

CARGO_TOML_PATH="$AWWW_DIR/Cargo.toml"
if [ ! -f "$CARGO_TOML_PATH" ]; then
  echo "❌ Could not find Cargo.toml at $CARGO_TOML_PATH"
  exit 1
fi

echo "Building 'awww' in release mode..."
sudo -u "$TARGET_USER" bash -c "source $TARGET_USER_HOME/.cargo/env && cd $AWWW_DIR && cargo build --release"

echo "Installing 'awww' and 'awww-daemon' binaries to /usr/bin/..."
sudo cp "$AWWW_DIR/target/release/awww" /usr/bin/awww
sudo cp "$AWWW_DIR/target/release/awww-daemon" /usr/bin/awww-daemon

echo "Installing wallpaper cycler script..."
sudo -u "$TARGET_USER" mkdir -p "$TARGET_USER_HOME/.local/bin"
sudo -u "$TARGET_USER" cp "$REPO_ROOT/bin/wallpaper-cycler.sh" "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"
sudo -u "$TARGET_USER" chmod +x "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"

echo "✅ 'awww' and wallpaper cycler script installed successfully."
