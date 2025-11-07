#!/bin/sh
#
# Installer script for 'awww' (the "capable" wallpaper daemon)
# This script is "capable" and "exciting":
# 1. It dynamically finds the MSRV from the awww repo's cargo.toml.
# 2. It checks the system 'rustc' against this dynamic MSRV.
# 3. If the system 'rustc' is too old, it installs Rust from source.
#
# Credits:
# - 'awww' (fka 'swww') by LGFae
#   https://codeberg.org/LGFae/awww
#

# --- Determine Target User and Home Directory ---
TARGET_USER=${1:-$(logname || whoami)}
TARGET_USER_HOME=${2:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}

if [ -z "$TARGET_USER" ] || [ -z "$TARGET_USER_HOME" ]; then
  echo "❌ [awww.sh] Could not determine target user or home directory."
  exit 1
fi
echo "Configuring AWWW for user: $TARGET_USER ($TARGET_USER_HOME)"

# --- Helper Functions ---
log_info() {
  echo "ℹ️ [awww.sh] $1"
}
log_error() {
  echo "❌ [awww.sh] $1"
  exit 1
}

# --- 1. Install Build Dependencies ---
log_info "Installing dependencies (git, lz4, jq, wget, rust...)"
sudo xbps-install -Sy rust git liblz4-devel \
  wayland-devel wayland-protocols scdoc \
  jq wget
[ $? -ne 0 ] && log_error "Failed to install dependencies."

# --- 2. Clone 'awww' Repo (We need this now) ---
log_info "Cloning 'awww' to get MSRV from cargo.toml..."
BUILD_DIR="$TARGET_USER_HOME/builds"
AWWW_DIR="$BUILD_DIR/awww"
sudo -u "$TARGET_USER" mkdir -p "$BUILD_DIR"

if [ -d "$AWWW_DIR" ]; then
  log_info "'awww' directory already exists. Pulling latest..."
  cd "$AWWW_DIR"
  sudo -u "$TARGET_USER" git pull
  cd "$OLDPWD" # Go back to the original dir
else
  sudo -u "$TARGET_USER" git clone https://codeberg.org/LGFae/awww.git "$AWWW_DIR"
fi

# --- 3. Dynamically Find MSRV (The "Capable" Fix) ---
CARGO_TOML_PATH="$AWWW_DIR/cargo.toml"
if [ ! -f "$CARGO_TOML_PATH" ]; then
  log_error "Could not find cargo.toml at $CARGO_TOML_PATH"
fi

# This command finds the 'rust-version' line and extracts the version
# e.g., 'rust-version = "1.87.0"' -> "1.87.0"
MIN_RUST=$(grep 'rust-version' "$CARGO_TOML_PATH" | cut -d'=' -f2 | tr -d '"' | tr -d ' ')

if [ -z "$MIN_RUST" ]; then
  log_error "Could not dynamically find 'rust-version' in $CARGO_TOML_PATH"
fi

log_info "Found 'awww' MSRV (Minimum Supported Rust Version): $MIN_RUST"

# --- 4. Check Rust Version ---
check_rust_version() {
  RUST_VERSION_STRING=$(rustc --version 2>/dev/null)
  if [ -z "$RUST_VERSION_STRING" ]; then
    log_info "Rust not found."
    return 1
  fi

  RUST_VERSION=$(echo "$RUST_VERSION_STRING" | cut -d' ' -f2)

  if ! printf '%s\n' "$MIN_RUST" "$RUST_VERSION" | sort -V -C; then
    log_info "System Rust version $RUST_VERSION is TOO OLD (need $MIN_RUST)."
    return 1
  else
    log_info "System Rust version $RUST_VERSION is compatible."
    return 0
  fi
}

# --- 5. Install/Update Rust from Source (if needed) ---
if ! check_rust_version; then
  log_info "Attempting to install Rust from source via rustup.rs..."

  log_info "Removing conflicting 'rust' package from xbps..."
  sudo xbps-remove -RF rust

  log_info "Downloading and running rustup-init.sh as user $TARGET_USER..."
  sudo -u "$TARGET_USER" curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sudo -u "$TARGET_USER" sh -s -- -y

  # Source the new environment
  . "$TARGET_USER_HOME/.cargo/env"

  log_info "Re-checking Rust version after install..."
  if ! check_rust_version; then
    log_error "Failed to install a compatible Rust version. Please install Rust >= $MIN_RUST manually."
  fi
fi

# --- 6. Remove Old 'swww' / 'swaybg' ---
log_info "Removing conflicting 'swww' and 'swaybg' packages..."
sudo xbps-remove -RF swww swaybg

# --- 7. Build 'awww' ---
log_info "Building 'awww' in $AWWW_DIR..."
cd "$AWWW_DIR"
sudo -u "$TARGET_USER" cargo build --release
[ $? -ne 0 ] && log_error "'cargo build' failed."
cd "$OLDPWD" # Go back

# --- 8. Install 'awww' Binaries ---
log_info "Installing 'awww' and 'awww-daemon' to /usr/bin/..."
sudo cp "$AWWW_DIR/target/release/awww" /usr/bin/awww
sudo cp "$AWWW_DIR/target/release/awww-daemon" /usr/bin/awww-daemon

# --- 9. Install Wallpaper Cycler Script ---
log_info "Installing wallpaper-cycler.sh to $TARGET_USER_HOME/.local/bin/..."
# 'install.sh' is run from repo root, so './bin/...' is the correct relative path
sudo -u "$TARGET_USER" mkdir -p "$TARGET_USER_HOME/.local/bin"
sudo -u "$TARGET_USER" cp ./bin/wallpaper-cycler.sh "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"
sudo -u "$TARGET_USER" chmod +x "$TARGET_USER_HOME/.local/bin/wallpaper-cycler.sh"

echo "✅ 'awww' and wallpaper cycler script installed successfully."
