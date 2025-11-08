#!/usr/bin/env bash
# installers/awww.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

echo "Configuring AWWW for user: $TARGET_USER ($TARGET_USER_HOME)"

echo "Installing dependencies..."
sudo xbps-install -Sy rust git liblz4-devel wayland-devel wayland-protocols scdoc jq wget || echo "Warning: Some dependencies may already be installed or failed."

BUILD_DIR="$TARGET_USER_HOME/builds"
AWWW_DIR="$BUILD_DIR/awww"
sudo -u "$TARGET_USER" mkdir -p "$BUILD_DIR"

if [ -d "$AWWW_DIR" ]; then
  echo "Updating existing 'awww' repo..."
  cd "$AWWW_DIR"
  sudo -u "$TARGET_USER" git pull
else
  echo "Cloning 'awww' repo..."
  sudo -u "$TARGET_USER" git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR"
fi

CARGO_TOML_PATH="$AWWW_DIR/cargo.toml"
if [ ! -f "$CARGO_TOML_PATH" ]; then
  echo "❌ Could not find cargo.toml at $CARGO_TOML_PATH"
  exit 1
fi

MIN_RUST=$(grep 'rust-version' "$CARGO_TOML_PATH" | cut -d'=' -f2 | tr -d '"' | tr -d ' ')

echo "Minimum Rust version required by awww: $MIN_RUST"

check_rust_version() {
  local RUST_VERSION_STRING
  RUST_VERSION_STRING=$(rustc --version 2>/dev/null || echo "")
  if [ -z "$RUST_VERSION_STRING" ]; then
    return 1
  fi
  local RUST_VERSION
  RUST_VERSION=$(echo "$RUST_VERSION_STRING" | cut -d' ' -f2)
  if ! printf '%s
' "$MIN_RUST" "$RUST_VERSION" | sort -V -C; then
    return 1
  fi
  return 0
}

if ! check_rust_version; then
  echo "Installing Rust via rustup..."
  sudo xbps-remove -RF rust || true
  sudo -u "$TARGET_USER" curl https://sh.rustup.rs -sSf | sudo -u "$TARGET_USER" sh -s -- -y
  . "$TARGET_USER_HOME/.cargo/env"
  if ! check_rust_version; then
    echo "❌ Failed to install compatible Rust version."
    exit 1
  fi
fi

echo "Removing conflicting swww and swaybg packages..."
sudo xbps-remove -RF swww swaybg || true

echo "Building 'awww'..."
cd "$AWWW_DIR"
sudo -u "$TARGET_USER" cargo build --release

echo "Installing 'awww' binaries..."
sudo cp "$AWWW_DIR/target/release/awww" /usr/bin/awww
sudo cp "$AWWW_DIR/target/release/awww-daemon" /usr/bin/awww-daemon

echo "Installing wallpaper cycler script..."
sudo -u "$TARGET_USER" mkdir -p "$TARGET_USER_HOME/.local/bin"
sudo -u "$TARGET_USER" cp "$REPO_ROOT/bin/wallpaper-cycler.sh" "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"
sudo -u "$TARGET_USER" chmod +x "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"

echo "✅ 'awww' and wallpaper cycler script installed."
