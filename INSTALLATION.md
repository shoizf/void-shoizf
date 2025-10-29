**[shoi@void-shoizf ~]$**

# Void Linux 🐧 & niri: shoizf's Setup Guide.

## 🚀 STAGE 1: Pre-Reboot Configuration

### 	1. **WiFi Connection** 

```shell
wpa_passphrase "YourSSID" "YourPassword" > /etc/wpa_supplicant/wpa_supplicant.conf
ip a
wpa_supplicant -B -i wlo1 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
dhcpcd wlo1
```

### 	2. Partition Disk & Mounting

#### 	2.1. Create partitions for EFI, /root, and swap

```shell
lsblk
fdisk /dev/nvme0n1
```

​	a. lsblk lists the disks in the system and their respective partitions. 

​	b. Select appropriate disk with lsblk to see the partitions in it. 

​	c. Use fdisk to create partitions on a disk.

​	d. The setup is exclusively for windows dual boot system considering 1G (at least) of esp 	directory (applicable to disk partition only).

#### 	2.2. Format partitions and activate swap 

​	> IMPORTANT: Replace partition numbers

​	> For example: 

```
[shoi@void-shoizf ~]$ lsblk /dev/nvme0n1
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0 953.9G  0 disk
├─nvme0n1p1 259:1    0   1.5G  0 part /boot/efi
├─nvme0n1p2 259:2    0    16M  0 part
├─nvme0n1p3 259:3    0 293.6G  0 part
├─nvme0n1p4 259:4    0   350G  0 part
├─nvme0n1p5 259:5    0   737M  0 part
├─nvme0n1p6 259:6    0     8G  0 part [SWAP]
└─nvme0n1p7 259:7    0   300G  0 part /
[shoi@void-shoizf ~]$
```

​	> The nvme0n1p1 of size 1.5G is a custom made partition on the SSD "nvme0n1" to host efi for windows and void. 

​	> We will target nvme0n1p6 & p7 for swap & root partitions respectively. 

​	> "fdisk" will help if you want to create new partitions. 

```shell
mkswap /dev/nvme0n1p6
mkfs.ext4 /dev/nvme0n1p7
swapon /dev/nvme0n1p6
```

#### 	2.3. Mounting the partitions.

```shell
mount /dev/nvme0n1p7 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
```

### 	3. Base System Setup

#### 	3.1. Install base system

```shell
REPO=https://repo-default.voidlinux.org/current
ARCH=x86_64
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
XBPS_ARCH=$ARCH xbps-install -Sy -r /mnt -R "$REPO" base-system xtools
```

#### 	3.2. Generate fstab and enter the xchroot

```shell
xgenfstab -U /mnt > /mnt/etc/fstab
xchroot /mnt /bin/bash
```

​	> xchroot is where the OS configuration & basic personalization occures.

#### 	3.3. System Configuration (inside xchroot)

##### 	3.3.1. Hostname, Keymap, Font, and Clock

```shell
$ echo "void-hp" > /etc/hostname
$ echo 'KEYMAP="us"' > /etc/rc.conf
$ xbps-install -S neovim terminus-font
$ echo 'FONT="ter-v22b"' >> /etc/rc.conf
$ EDITOR=nvim 
```

​	Note:- We are NOT setting HARDWARECLOCK because your Windows should 	configured to use UTC. 

##### 	3.3.2. Enable your chosen locale.

```shell
nvim /etc/default/libc-locales
```

​	> Inside, un-comment the line for "en_IN UTF-8" (x for delete character & Esc, :wq for save with changes).

##### 	3.3.3. Generate the locale.

```shell
xbps-reconfigure -f glibc-locales
```

##### 	3.3.4. Set the default LANG variable.

```shell
echo "LANG=en_IN.UTF-8" > /etc/locale.conf
```

##### 	3.3.5. Set the timezone.

```shell
ln -sf /usr/share/zoneinfo/Asia/Dubai /etc/localtime
```

##### 	3.3.6. User and Password Setup

```shell
passwd
useradd -m -s /bin/bash -G wheel,audio,video,input,network,storage, <uname>
passwd <uname>
```

##### 	3.3.7. Sudoers Configuration

​	> Choose ONE of the following methods to grant sudo access to the 'wheel' group.

​	a. Method A (Manual & Recommended): Run this command to safely edit the sudoers file.

```shell
visudo
```

​	> Inside the editor, find the line '# %wheel ALL=(ALL) ALL' and remove the '# ' from the start of that line. Then save and exit. (x for delete character, & Esc, :wq to exit with save).

​	b. Method B (Automated): Uncomment the line below to run the automated command.

```shell
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
```

##### 	3.3.8. System Update and Core Packages

```shell
xbps-install -Su
xbps-install -S void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
```

#### 	3.4. GRUB Stage 1: Installation (Inside xchroot)

```shell
xbps-install -S grub-x86_64-efi efibootmgr os-prober ntfs-3g
```

##### 	3.4.1. Configure os-prober and add NVIDIA modeset to the kernel parameters.

```shell
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
```

​	> Add the following:  

```shell
nvim /etc/default/grub
"nvidia-drm.modeset=1"
```

​	> To the end of the line:

```shell
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"
```

​	> The new line should now look like: 

```shell
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 ... nvidia-drm.modeset=1"
```

​	> In nvim: 

​	> i - for insert mode, Esc, :wq to exit with changes. 

##### 	3.4.2. Install GRUB to the EFI directory

```shell
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void"
```

##### 	3.4.3. Generate a TEMPORARY config that will let you boot Void Linux

```shell
grub-mkconfig -o /boot/grub/grub.cfg
```

#### 	3.5. Finalization

​	> Final reconfiguration, exit, and reboot!

```shell
xbps-reconfigure -fa
exit
umount -R /mnt
reboot
```

## 🚀 STAGE 2: Post-Reboot Configuration

### 	1. System Update

```shell
sudo xbps-install -Syu
```

### 	2. GRUB Stage 2: Add Windows

```shell
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### 	3. Install CPU Microcode

​	> This package from the nonfree repo provides critical bug fixes for your Intel CPU.sudo 

```shell
sudo xbps-install -Sy intel-ucode
```

### 	4. NVIDIA Prop Driver Installation & Blacklisting "nouveau" 
#### 		4.1. Install Kernel Headers

```shell
uname -r
sudo xbps-install -S linux<version>-headers
```

​	> example: if uname -r = 6.12.xxxx then, the above command will become: linux6.12-headers

#### 		4.2. Install the NVIDIA drivers and shoizf setup.

```shell
git clone https://github.com/shoizf/void-shoizf.git
cd void-shoizf
chmod +x install.sh
./install.sh
```

#### 	4.3. Blacklist the default Nouveau driver to prevent conflicts

```shell
echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
```

### 	5. Regenerate Initramfs (VITAL STEP) 

​	> This applies the microcode, driver, and module changes to your boot image.

​	> First, find your kernel package version (e.g., 'linux6.8' from '6.8.9_1'):

```shell
uname -r
```

​	> Then, run the reconfigure command with that version.

```shell
sudo xbps-reconfigure -f linux<version>
```

### 	6. Reboot

​	> A final reboot is needed for the microcode and drivers to load.

```shell
sudo shutdown -r now
```

### 	7. NVIDIA Driver Verification (After second reboot) 

#### 	7.1. Checking for propreitory driver

```shell
lsmod | grep nvidia
```

​	>  If succeeded expect an output similar to the following:

```shell
[shoi@void-shoizf ~]$ lsmod | grep nvidia
nvidia_drm            143360  8
nvidia_modeset       1929216  3 nvidia_drm
nvidia              111505408  40 nvidia_modeset
drm_ttm_helper         16384  2 nvidia_drm,xe
drm_kms_helper        241664  5 drm_display_helper,drm_ttm_helper,nvidia_drm,xe,i915
drm                   753664  28 gpu_sched,i2c_hid,drm_kms_helper,drm_exec,drm_gpuvm,drm_suballoc_helper,drm_display_helper,nvidia,drm_buddy,drm_ttm_helper,nvidia_drm,xe,i915,ttm
video                  81920  3 xe,i915,nvidia_modeset
[shoi@void-shoizf ~]$
```

####  	7.2. Checking for nouveau blacklisting

​	> Expect no output if succeeded. 

```
lsmod | grep nouveau
```

#### 	7.3. Summary of your system 

```
nvidia-smi
```

​	> Expect output if succeeded

## 🚀 STAGE 3: Niri Wayland Desktop Environment

### 	1. LazyVim: 

```shell
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
```

### 	2. Oh-my tmux: 

```shell
curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash
```

### 	3. Reboot:

```shell
sudo shutdown -r now
```

