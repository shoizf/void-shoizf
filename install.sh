#!/bin/sh

# Set the package manager command and system flags
PKG_CMD="sudo xbps-install -Sy"

# List of all packages to install, separated by spaces and wrapped for clarity
PACKAGES="\
	noto-fonts-ttf-variable \
	noto-fonts-emoji \
	niri \
xdg-desktop-portal-wlr \
wayland \
xwayland-satellite \
polkit-kde-agent \
swaybg \
swayidle \
alacritty \
walker \
Waybar \
firefox \
sddm \
tmux \
font-firacode \
ripgrep \
fd \
tree \
xorg-server \
xf86-input-libinput \
dbus-libs \
dbus-x11 \
brightnessctl \
cups \
cups-filters \
acpi \
jq \
font-awesome \
dateutils \
wlr-randr \
xdg-desktop-portal \
power-profiles-daemon \
procps-ng \
NetworkManager \
networkmanager-dmenu \
nm-tray \
acpi \
playerctl"

echo "Starting package installation..."

# Execute the installation command
$PKG_CMD $PACKAGES

if [ $? -eq 0 ]; then
    echo "🎉 All packages installed successfully!"
    echo "Remember to enable and start services like sddm and dbus after a reboot or manual command."
else
    echo "❌ Package installation failed! Check the output for errors."
fi

# Ensure the directory for udev rules exists
UDEV_RULES_DIR="/etc/udev/rules.d"
if [ ! -d "$UDEV_RULES_DIR" ]; then
    echo "Creating directory $UDEV_RULES_DIR..."
    mkdir -p "$UDEV_RULES_DIR"
fi

# Create udev rules file for backlight brightness permissions
UDEV_RULES_FILE="$UDEV_RULES_DIR/90-backlight.rules"

echo "Creating udev rules for backlight permissions at $UDEV_RULES_FILE..."

cat <<EOF > $UDEV_RULES_FILE
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF

echo "Reloading udev rules..."
udevadm control --reload
udevadm trigger

# Add current user to necessary groups (excluding virtualization groups)
GROUPS_TO_ADD="video lp"

for group in $GROUPS_TO_ADD; do
    if id -nG "$SUDO_USER" | grep -qw $group; then
        echo "User $SUDO_USER is already in the $group group."
    else
        echo "Adding user $SUDO_USER to $group group..."
        usermod -a -G $group "$SUDO_USER"
        echo "User $SUDO_USER added to $group group. You may need to log out and log back in for this to take effect."
    fi
done 

# Download, chmod +x and execute niri.sh installer script
echo "Configuring niri"

chmod +x ./installers/niri.sh

if ./installers/niri.sh; then
	echo "✅ niri configuration finished succesfully!"
else
	echo "❌ niri configuration failed."
fi

# Download, chmod +x and execute sddm_astronaut.sh installer script
echo "Downloading and executing SDDM Astronaut theme installer script..."

chmod +x ./installers/sddm_astronaut.sh

if ./installers/sddm_astronaut.sh; then
    echo "✅ SDDM Astronaut theme installation finished successfully!"
else
    echo "❌ SDDM Astronaut theme installation failed."
fi

echo "Starting GRUB theme installation..."
chmod +x ./installers/grub.sh
if sudo ./installers/grub.sh; then
    echo "✅ GRUB theme setup completed successfully."
else
    echo "❌ GRUB theme setup failed!"
fi

# Execute NVIDIA installer script
echo "Executing NVIDIA installer script..."
chmod +x ./installers/nvidia.sh
if ./installers/nvidia.sh; then
    echo "✅ NVIDIA installer finished successfully!"
else
    echo "❌ NVIDIA installer failed!"
fi

# Execute Vulkan Intel installer script
echo "Executing Vulkan Intel installer script..."
chmod +x ./installers/vulkan-intel.sh
if ./installers/vulkan-intel.sh; then
    echo "✅ Vulkan Intel installer finished successfully!"
else
    echo "❌ Vulkan Intel installer failed!"
fi

# Execute Intel GPU installer script
echo "Executing Intel GPU installer script..."
chmod +x ./installers/intel.sh
if ./installers/intel.sh; then
    echo "✅ Intel GPU installer finished successfully!"
else
    echo "❌ Intel GPU installer failed!"
fi

echo "Applying shoizf configuration..."


