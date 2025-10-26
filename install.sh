#!/bin/sh

# Set the package manager command and system flags
PKG_CMD="sudo xbps-install -Sy"

# List of all packages to install, separated by spaces and wrapped for clarity
PACKAGES="\
    nvidia nvidia-libs nvidia-libs-32bit \
    nvidia-vaapi-driver mesa-dri mesa-dri-32bit mesa-demos \
    noto-fonts-ttf-variable noto-fonts-emoji niri \
    xdg-desktop-portal-wlr wayland xwayland-satellite \
    polkit-kde-agent swaybg swayidle alacritty walker Waybar \
    firefox sddm tmux font-firacode ripgrep fd tree xorg-server \
    xf86-input-libinput xf86-video-intel dbus-libs dbus-x11"

echo "Starting package installation..."

# Execute the installation command
# The 'xargs' command handles the package list, preventing command line length issues
$PKG_CMD $PACKAGES

# Check the exit status of the installation command
if [ $? -eq 0 ]; then
    echo "🎉 All packages installed successfully!"
    echo "Remember to enable and start services like sddm and dbus after a reboot or manual command."
else
    echo "❌ Package installation failed! Check the output for errors."
fi
