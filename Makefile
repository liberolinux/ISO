# Libero GNU/Linux - Admin CD i486 Makefile
# Based on Gentoo Linux
# Maintainer: André Machado
# License: GPL-3.0

# Use bash for Makefile recipes that rely on arrays and other bashisms.
SHELL := /bin/bash

DISTRO_NAME = Libero
VERSION = 1.2
ARCH = i486
ISO_NAME = libero-admincd-$(ARCH)-$(VERSION).iso

# Directories
WORK_DIR = work
CHROOT_DIR = $(WORK_DIR)/chroot
ISO_DIR = $(WORK_DIR)/iso
STAGE3_DIR = $(WORK_DIR)/stage3

# URLs and files
GENTOO_MIRROR = https://distfiles.gentoo.org/releases/x86/autobuilds
STAGE3_TARBALL = stage3-i486-systemd-*.tar.xz
PORTAGE_SNAPSHOT = portage-latest.tar.xz

# LFS required packages
LFS_PACKAGES = \
    sys-boot/grub \
    sys-kernel/gentoo-kernel-bin \
    app-admin/sudo \
    net-misc/dhcpcd \
    net-wireless/wpa_supplicant \
    sys-fs/dosfstools \
	sys-fs/squashfs-tools \
	sys-fs/lvm2 \
	sys-fs/xfsprogs \
	sys-fs/btrfs-progs \
	sys-fs/e2fsprogs \
	sys-fs/reiserfsprogs \
	sys-fs/jfsutils \
	sys-fs/xfsdump \
	sys-fs/fuse \
	sys-fs/ntfs3g \
    sys-block/parted \
	dev-util/dialog \
	net-misc/ntp \
	sys-apps/gptfdisk \
	sys-fs/cryptsetup \
	sys-fs/mdadm \
	app-shells/fish \
	app-misc/tmux \
	app-misc/tmux-mem-cpu-load \
	sys-process/htop \
	dev-vcs/git \
	app-editors/vim \
	app-editors/emacs \
	net-analyzer/nmap \
	sys-apps/ethtool \
	mail-client/alpine \
	net-irc/irssi \
	net-vpn/tor \
	net-ftp/ftp \
	dev-python/docutils \
	net-misc/openssh \
	app-misc/neofetch \
	net-misc/networkmanager \
	sys-apps/pciutils \
	sys-apps/usbutils \
	sys-apps/pv \
	sys-apps/lshw \
	sys-power/acpi \
	app-arch/unzip \
	app-arch/p7zip \
	app-arch/zstd \
	app-arch/lz4 \
	app-arch/xz-utils \
	app-arch/bzip2 \
	app-arch/gzip \
	net-misc/iputils \
	net-analyzer/netcat \
	net-analyzer/tcpdump \
	media-sound/alsa-utils \
	net-analyzer/iftop \
	net-analyzer/mtr \
	net-wireless/iw \
	net-wireless/wireless-tools \
	app-crypt/gnupg \
	net-misc/rsync \
	dev-libs/openssl \
	dev-debug/gdb \
	dev-debug/strace \
	dev-debug/valgrind \
	sys-apps/lm-sensors \
	app-misc/mc \
	sys-apps/dmidecode \
	media-libs/libsndfile \
	sys-process/iotop \
	app-text/tree \
	app-misc/jq \
	sys-fs/inotify-tools \
	app-portage/gentoolkit \
	app-portage/eix \
	app-portage/portage-utils \
	sys-apps/mlocate \
	app-admin/testdisk \
	app-admin/sysstat \
	media-sound/moc \
	net-misc/whois \
	net-misc/iperf \
	net-misc/bridge-utils \
	net-firewall/iptables \
	sys-apps/smartmontools \
	sys-process/daemontools \
	sys-fs/ncdu \
	sys-apps/memtester \
	sys-apps/memtest86+ \
	app-misc/colordiff \
	sys-fs/hfsutils \
	sys-fs/hfsplusutils \
	sys-apps/hdparm

# QEMU options
QEMU_MEMORY = 2048
QEMU_CPU = qemu32
QEMU_OPTS = -m $(QEMU_MEMORY) -cpu $(QEMU_CPU) -enable-kvm -boot d -netdev user,id=net0 -device e1000,netdev=net0

.PHONY: all check-deps download prepare chroot install-libero setup-grub squashfs build-iso debug-iso qemu qemu-hd clean help version size-check

all: check-deps download prepare chroot install-libero setup-grub squashfs build-iso

check-deps:
	@echo "Checking for required dependencies..."

	@which bash >/dev/null || { echo "bash not found"; exit 1; }
	@which tar >/dev/null || { echo "tar not found"; exit 1; }
	@which wget >/dev/null || { echo "wget not found"; exit 1; }
	@which unzip >/dev/null || { echo "unzip not found"; exit 1; }
	@which sudo >/dev/null || { echo "sudo not found"; exit 1; }
	@test -x /usr/sbin/chroot || test -x /sbin/chroot || { echo "chroot not found"; exit 1; }
	@which mksquashfs >/dev/null || { echo "squashfs-tools not found"; exit 1; }
	@which xorriso >/dev/null || { echo "xorriso not found"; exit 1; }
	@which grub-mkrescue >/dev/null || { echo "grub-mkrescue not found"; exit 1; }
	@which qemu-system-i386 >/dev/null || { echo "qemu not found"; exit 1; }

	@echo "All dependencies are satisfied."
	@echo "Ready to build $(DISTRO_NAME) Admin CD for $(ARCH)."

download:
	@echo "Downloading Gentoo stage3 and portage..."

	mkdir -p $(WORK_DIR)
	cd $(WORK_DIR) && wget $(GENTOO_MIRROR)/latest-stage3-i486-systemd.txt || { echo "Failed to download stage3 list"; exit 1; }
	cd $(WORK_DIR) && wget $(GENTOO_MIRROR)/$$(grep -v '^#' latest-stage3-i486-systemd.txt | grep '.tar.xz' | head -1 | cut -d' ' -f1) || { echo "Failed to download stage3"; exit 1; }
	cd $(WORK_DIR) && wget https://distfiles.gentoo.org/snapshots/$(PORTAGE_SNAPSHOT) || { echo "Failed to download portage"; exit 1; }

prepare:
	@echo "Preparing chroot environment..."

	mkdir -p $(CHROOT_DIR) $(ISO_DIR)
	cd $(WORK_DIR) && sudo tar xpf stage3-*.tar.xz -C ../$(CHROOT_DIR) --xattrs-include='*.*' --numeric-owner
	cd $(WORK_DIR) && sudo tar xf $(PORTAGE_SNAPSHOT) -C ../$(CHROOT_DIR)/usr

chroot:
	@echo "Setting up chroot for $(DISTRO_NAME)..."
	sudo cp /etc/resolv.conf $(CHROOT_DIR)/etc/
	sudo mount --bind /dev $(CHROOT_DIR)/dev
	sudo mkdir -p $(CHROOT_DIR)/dev/pts
	sudo mount --bind /dev/pts $(CHROOT_DIR)/dev/pts
	sudo mount --bind /proc $(CHROOT_DIR)/proc
	sudo mount --bind /sys $(CHROOT_DIR)/sys

install-libero:
	@echo "Installing Libero GNU/Linux required packages..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "emerge --sync"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'MAKEOPTS=\"-j$(shell nproc)\"' >> /etc/portage/make.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /etc/portage/package.use"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '>=sys-kernel/installkernel-50 dracut' > /etc/portage/package.use/libero"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'net-misc/iputils -filecaps' >> /etc/portage/package.use/libero"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'app-portage/portage-utils -openmp' >> /etc/portage/package.use/libero"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'net-wireless/wpa_supplicant dbus' >> /etc/portage/package.use/libero"
		
	sudo chroot $(CHROOT_DIR) /bin/bash -c "sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "locale-gen"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "eselect locale set en_US.utf8"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "env-update && source /etc/profile"

	@echo "Configuring CMAKE version..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /etc/portage/package.accept_keywords"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '=dev-build/cmake-3.31.9-r1 **' >> /etc/portage/package.accept_keywords/cmake"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "emerge =dev-build/cmake-3.31.9-r1"

	@echo "Setting up GPG verification for binary packages..."
	
	sudo chroot $(CHROOT_DIR) /bin/bash -c "getuto" || echo "Warning: getuto failed, continuing without binary package verification"

	@echo "Configuring binary packages for faster builds..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'FEATURES=\"getbinpkg binpkg-logs\"' >> /etc/portage/make.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'PORTAGE_BINHOST=\"https://distfiles.gentoo.org/releases/x86/binpackages/23.0/i486/\"' >> /etc/portage/make.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'EMERGE_DEFAULT_OPTS=\"--getbinpkg --usepkg\"' >> /etc/portage/make.conf"

	@echo "Installing required Linux Firmware for $(DISTRO_NAME)..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE' >> /etc/portage/package.license"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "emerge sys-kernel/linux-firmware"

	@echo "Installing required packages for $(DISTRO_NAME)..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "emerge $(LFS_PACKAGES)"

	@echo "Configuring network and hostname..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'AdminCD' > /etc/hostname"

	@echo "Change OS release information..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'NAME=\"Libero GNU/Linux\"' > /usr/lib/os-release"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ID=libero' >> /usr/lib/os-release"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'PRETTY_NAME=\"Libero GNU/Linux $(VERSION)\"' >> /usr/lib/os-release"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ANSI_COLOR=\"1;34\"' >> /usr/lib/os-release"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'HOME_URL=\"https://libero.eu.org/\"' >> /usr/lib/os-release"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'VERSION_ID=\"$(VERSION)\"' >> /usr/lib/os-release"

	@echo "Setting up network configuration..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'nameserver 9.9.9.9' > /etc/resolv.conf"

	@echo "Configuring system for $(DISTRO_NAME)..."
	sudo sh -c 'echo "$(DISTRO_NAME) $(VERSION)" > $(CHROOT_DIR)/etc/gentoo-release'

	@echo "Configuring Live CD initramfs..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /etc/dracut.conf.d"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'add_dracutmodules+=\" dmsquash-live network base dm systemd overlayfs \"' > /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'filesystems+=\" squashfs iso9660 overlay ext4 \"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'drivers+=\" cdrom sr_mod loop dm-mod overlay ata_piix ahci usb_storage uas xhci_hcd xhci_pci ehci_hcd ehci_pci ohci_hcd uhci_hcd sd_mod \"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'omit_dracutmodules+=\" plymouth \"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'persistent_policy=\"by-label\"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'compress=\"zstd\"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'hostonly=\"no\"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'hostonly_cmdline=\"no\"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'install_items+=\" /sbin/blkid /bin/findmnt /usr/bin/lsblk \"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "dracut --force --kver \$$(ls /lib/modules/ | head -1) --no-hostonly --no-hostonly-cmdline --add 'dmsquash-live dm overlayfs'"

	@echo "Creating live user and configuring auto-login..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "groupadd libero || true"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "useradd -m -g libero -G audio,video,wheel -s /bin/bash libero || true"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'libero:libero' | chpasswd"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'root:libero' | chpasswd"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /etc/systemd/system/getty@tty1.service.d"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '[Unit]' > /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ConditionKernelCommandLine=!libero.mode=installer' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '[Service]' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ExecStart=' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ExecStart=-/sbin/agetty --autologin libero --noclear %I \$$TERM' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"

	@echo "Change Shell for root and libero user to fish..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "chsh -s /usr/bin/fish root"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "chsh -s /usr/bin/fish libero"

	@echo "Terminal Console Background to White and Text to Black..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /root/.config/fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /home/libero/.config/fish"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '    printf \"\\033]10;#000000\\007\"     # foreground (black text)' > /root/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '    printf \"\\033]11;#ffffff\\007\"     # background (white)' >> /root/.config/fish/config.fish"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '    printf \"\\033]10;#000000\\007\"     # foreground (black text)' > /home/libero/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '    printf \"\\033]11;#ffffff\\007\"     # background (white)' >> /home/libero/.config/fish/config.fish"

	@echo "Configuring fish shell for root and libero user..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g fish_greeting \"Welcome to Libero GNU/Linux $(VERSION)!\"' >> /root/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g fish_greeting \"Welcome to Libero GNU/Linux $(VERSION)!\"' >> /home/libero/.config/fish/config.fish"
	
	@echo "Make tmux load after Root Login..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'if status is-login' >> /root/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '    cd \$$HOME' >> /root/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'end' >> /root/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '' >> /root/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'if status is-interactive; and not set -q TMUX' >> /root/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '                exec tmux' >> /root/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'end' >> /root/.config/fish/config.fish"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'if status is-login' >> /home/libero/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '    cd \$$HOME' >> /home/libero/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'end' >> /home/libero/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '' >> /home/libero/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'if status is-interactive; and not set -q TMUX' >> /home/libero/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '                exec tmux' >> /home/libero/.config/fish/config.fish"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'end' >> /home/libero/.config/fish/config.fish"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "chown -R libero:libero /home/libero/.config"
	
	@echo "Configure tmux for better terminal experience..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g status-interval 1' > /root/.tmux.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g status-left \"#[fg=green,bg=black]#(tmux-mem-cpu-load --colors --interval 1)\"' >> /root/.tmux.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g status-left-length 60' >> /root/.tmux.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g status-right \"[#(date +'\''%d/%m/%Y %H:%M'\'')]\"' >> /root/.tmux.conf"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g status-interval 1' > /home/libero/.tmux.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g status-left \"#[fg=green,bg=black]#(tmux-mem-cpu-load --colors --interval 1)\"' >> /home/libero/.tmux.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g status-left-length 60' >> /home/libero/.tmux.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'set -g status-right \"[#(date +'\''%d/%m/%Y %H:%M'\'')]\"' >> /home/libero/.tmux.conf"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "chown libero:libero /home/libero/.tmux.conf"

	@echo "Add user Libero and root to sudoers..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'libero ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'root ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"	

	@echo "Setup Ultimate Vim  for Root and Libero user..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "git clone --depth=1 https://github.com/amix/vimrc.git /opt/vim_runtime"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "cd /opt/vim_runtime && python update_plugins.py"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "sh /opt/vim_runtime/install_awesome_parameterized.sh /opt/vim_runtime root libero"

	@echo "Setting up Exordium Emacs configuration for libero user..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "git clone --depth=1 https://github.com/emacs-exordium/exordium.git /home/libero/.emacs.d"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "chown -R libero:libero /home/libero/.emacs.d"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "sudo -u libero emacs --batch -l /home/libero/.emacs.d/init.el --eval='(require (quote package))' --eval='(package-refresh-contents)' --eval='(dolist (pkg package-selected-packages) (unless (package-installed-p pkg) (ignore-errors (package-install pkg))))' --eval='(if (and (fboundp (quote native-comp-available-p)) (native-comp-available-p) (fboundp (quote batch-native-compile))) (progn (message \"Using native compilation...\") (batch-native-compile \"/home/libero/.emacs.d\")) (progn (message \"Native compilation unavailable, using byte compilation...\") (byte-recompile-directory \"/home/libero/.emacs.d\" 0)))'"

	@echo "Setting up Exordium Emacs configuration for root user..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "git clone --depth=1 https://github.com/emacs-exordium/exordium.git /root/.emacs.d"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "emacs --batch -l /root/.emacs.d/init.el --eval='(require (quote package))' --eval='(package-refresh-contents)' --eval='(dolist (pkg package-selected-packages) (unless (package-installed-p pkg) (ignore-errors (package-install pkg))))' --eval='(if (and (fboundp (quote native-comp-available-p)) (native-comp-available-p) (fboundp (quote batch-native-compile))) (progn (message \"Using native compilation...\") (batch-native-compile \"/root/.emacs.d\")) (progn (message \"Native compilation unavailable, using byte compilation...\") (byte-recompile-directory \"/root/.emacs.d\" 0)))'"

	@echo "Enabling network services..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "systemctl enable dhcpcd.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "systemctl enable NetworkManager.service"

	@echo "Cloning Libero installer into /opt/libero-installer..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "git clone https://github.com/liberolinux/LGLI /opt/LGLI"

	@echo "Libero installer cloned to /opt/LGLI Compiling..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "cd /opt/LGLI && make"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "chmod +x /opt/LGLI/libero-installer"

	@echo "Libero installer compiled."

	@echo "Setting up Libero Installer service..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /etc/systemd/system"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '[Unit]' > /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'Description=Libero Gentoo Installer' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ConditionKernelCommandLine=libero.mode=installer' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'After=network.target systemd-user-sessions.service' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '[Service]' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'Type=simple' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'TTYPath=/dev/tty1' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'StandardInput=tty' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'StandardOutput=journal' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ExecStart=/opt/LGLI/libero-installer' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'Restart=on-failure' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '[Install]' >> /etc/systemd/system/libero-installer.service"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'WantedBy=multi-user.target' >> /etc/systemd/system/libero-installer.service"
	
	sudo chroot $(CHROOT_DIR) /bin/bash -c "systemctl enable libero-installer.service"

	@echo "Configure zram for better performance..."

	sudo mkdir -p $(CHROOT_DIR)/etc/systemd/system
	sudo sh -c 'echo "[Unit]" > $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "Description=Setup zram swap for Live CD" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "Documentation=man:zram" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "DefaultDependencies=no" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "After=systemd-modules-load.service systemd-udev-settle.service" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "Before=swap.target sysinit.target" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "Wants=systemd-modules-load.service" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "[Service]" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "Type=oneshot" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "RemainAfterExit=yes" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "ExecStart=/bin/bash -c '\''modprobe zram num_devices=1'\''" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "ExecStart=/bin/bash -c '\''echo lz4 > /sys/block/zram0/comp_algorithm'\''" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c "echo 'ExecStart=/bin/bash -c \"awk \\\"/MemTotal/{print \\\$$2}\\\" /proc/meminfo | awk \\\"{print \\\$$1 * 1024 / 2}\\\" > /sys/block/zram0/disksize\"' >> ${CHROOT_DIR}/etc/systemd/system/zram-swap.service"
	sudo sh -c 'echo "ExecStart=/bin/bash -c '\''mkswap /dev/zram0'\''" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "ExecStart=/bin/bash -c '\''swapon /dev/zram0 -p 10'\''" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "ExecStop=/bin/bash -c '\''swapoff /dev/zram0'\''" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "ExecStop=/bin/bash -c '\''echo 1 > /sys/block/zram0/reset'\''" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "TimeoutSec=30" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "[Install]" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'
	sudo sh -c 'echo "WantedBy=swap.target" >> $(CHROOT_DIR)/etc/systemd/system/zram-swap.service'

	sudo chroot $(CHROOT_DIR) /bin/bash -c "systemctl enable zram-swap.service"

	@echo "Libero GNU/Linux packages installed."

size-check:
	@echo "=== Size Analysis ==="
	
	@if [ -d "$(CHROOT_DIR)" ]; then \
		echo "Chroot directory size:"; \
		du -sh $(CHROOT_DIR); \
		echo ""; \
		echo "Largest directories in chroot:"; \
		sudo du -sh $(CHROOT_DIR)/* 2>/dev/null | sort -hr | head -10; \
		echo ""; \
	fi
	@if [ -f "$(ISO_DIR)/image.squashfs" ]; then \
		echo "SquashFS image size:"; \
		ls -lh $(ISO_DIR)/image.squashfs; \
		echo ""; \
	fi
	@if [ -d "$(ISO_DIR)" ]; then \
		echo "ISO directory size:"; \
		du -sh $(ISO_DIR); \
		echo ""; \
		echo "Largest directories in ISO:"; \
		sudo du -sh $(ISO_DIR)/* 2>/dev/null | sort -hr | head -10; \
		echo ""; \
	fi
	@if [ -f "$(ISO_NAME)" ]; then \
		echo "Final ISO size:"; \
		ls -lh $(ISO_NAME); \
		echo ""; \
	fi

setup-grub:
	@echo "Setting up GRUB configuration..."

	sudo mkdir -p $(ISO_DIR)/boot/grub
	sudo sh -c 'echo "set default=0" > $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "set timeout=10" >> $(ISO_DIR)/boot/grub/grub.cfg'
	
	sudo sh -c 'echo "# Solarized Light Theme for GRUB" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "# Base colors: light background with dark text" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "set color_normal=dark-gray/light-gray" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "set color_highlight=white/cyan" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "set menu_color_normal=dark-gray/light-gray" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "set menu_color_highlight=white/cyan" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "set gfxpayload=keep" >> $(ISO_DIR)/boot/grub/grub.cfg'
	
	sudo sh -c 'echo "insmod all_video" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod gzio" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod part_msdos" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod iso9660" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod squash4" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "" >> $(ISO_DIR)/boot/grub/grub.cfg'
	
	# Add a visual separator for the Solarized theme
	sudo sh -c 'echo "# =================================" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "#   Libero GNU/Linux Boot Menu     " >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "# =================================" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "" >> $(ISO_DIR)/boot/grub/grub.cfg'
	
	sudo sh -c 'echo "menuentry \"$(DISTRO_NAME) GNU/Linux - Admin CD\" {" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    search --no-floppy --set=root --label LIBERO_12" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    linux /boot/vmlinuz root=live:LABEL=LIBERO_12 rd.live.image rd.live.dir=/ rd.live.squashimg=image.squashfs libero.mode=admin quiet loglevel=0" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    initrd /boot/initrd" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "}" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "menuentry \"$(DISTRO_NAME) GNU/Linux - Installer\" {" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    search --no-floppy --set=root --label LIBERO_12" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    linux /boot/vmlinuz root=live:LABEL=LIBERO_12 rd.live.image rd.live.dir=/ rd.live.squashimg=image.squashfs libero.mode=installer quiet loglevel=0" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    initrd /boot/initrd" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "}" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "" >> $(ISO_DIR)/boot/grub/grub.cfg'

	@echo "GRUB setup complete."

squashfs:
	@echo "Creating highly compressed squashfs image..."

	sudo mksquashfs $(CHROOT_DIR) $(ISO_DIR)/image.squashfs \
		-no-exports -comp zstd -Xcompression-level 22 \
		-e proc dev sys tmp var/tmp var/cache var/log/portage \
		-no-progress -no-duplicates -always-use-fragments

	@echo "Squashfs image created at $(ISO_DIR)/image.squashfs"
	@echo "Squashfs size: $$(du -h $(ISO_DIR)/image.squashfs | cut -f1)"

build-iso:
	@echo "Creating ISO directory structure..."

	sudo mkdir -p $(ISO_DIR)/boot/grub
	sudo cp $(CHROOT_DIR)/boot/kernel-* $(ISO_DIR)/boot/vmlinuz
	sudo cp $(CHROOT_DIR)/boot/initramfs-* $(ISO_DIR)/boot/initrd

	@echo "Building hybrid ISO with grub-mkrescue..."

	sudo rm -f $(ISO_NAME); \
	sudo grub-mkrescue -o $(ISO_NAME) $(ISO_DIR) \
		-R -volid LIBERO_12 -iso-level 3 -J -joliet-long || exit $$?

	@echo "ISO image created: $(ISO_NAME)"
	@FINAL_SIZE=$$(du -h $(ISO_NAME) | cut -f1); \
	echo "Final ISO size: $${FINAL_SIZE}"; \
	ls -lh $(ISO_NAME)

debug-iso:
	@echo "Checking ISO contents..."
	
	@echo "=== Boot files ==="

	ls -la $(ISO_DIR)/boot/

	@echo "=== GRUB config ==="

	cat $(ISO_DIR)/boot/grub/grub.cfg

	@echo "=== Squashfs info ==="

	ls -lh $(ISO_DIR)/image.squashfs

qemu-debug:
	@echo "Starting QEMU with debug output..."

	qemu-system-i386 $(QEMU_OPTS) -cdrom $(ISO_NAME) -serial stdio -d guest_errors


qemu:
	@echo "Starting QEMU with $(DISTRO_NAME) ISO..."

	qemu-system-i386 $(QEMU_OPTS) -cdrom $(ISO_NAME)

qemu-hd:
	@echo "Starting QEMU with hard disk and CD..."

	qemu-img create -f qcow2 libero-hd.qcow2 10G
	qemu-system-i386 $(QEMU_OPTS) -hda libero-hd.qcow2 -cdrom $(ISO_NAME)

clean:
	@echo "Cleaning build environment..."
	
	sudo umount $(CHROOT_DIR)/dev/pts $(CHROOT_DIR)/dev $(CHROOT_DIR)/proc $(CHROOT_DIR)/sys 2>/dev/null || true
	sudo rm -rf $(WORK_DIR) $(ISO_NAME) libero-hd.qcow2 || true

help:
	@echo "Makefile for $(DISTRO_NAME) Admin CD"
	@echo "Usage:"
	@echo "  make all          - Build the entire Admin CD"
	@echo "  make check-deps   - Check for required dependencies"
	@echo "  make download     - Download Gentoo stage3 and portage snapshot"
	@echo "  make prepare      - Prepare the chroot environment"
	@echo "  make chroot       - Set up the chroot environment"
	@echo "  make install-libero - Install Libero GNU/Linux packages"
	@echo "  make prepare-installer - Clone Libero installer sources into the ISO chroot"
	@echo "  make setup-grub   - Set up GRUB configuration"
	@echo "  make squashfs     - Create Squashfs image"
	@echo "  make build-iso    - Build the ISO image"
	@echo "  make size-check   - Monitor build sizes and space usage"
	@echo "  make debug-iso    - Check ISO contents and GRUB config"
	@echo "  make qemu-debug   - Start QEMU with debug output"
	@echo "  make qemu         - Start QEMU with the ISO"
	@echo "  make qemu-hd      - Start QEMU with hard disk and ISO"
	@echo "  make clean        - Clean the build environment"
	@echo "  make help         - Show this help message"
	@echo "  make version      - Show version information"

version:
	@echo "$(DISTRO_NAME) version $(VERSION) for $(ARCH)"
	@echo "Built with Love by the Libero GNU/Linux Project"
	@echo "For more information, visit https://libero.eu.org"
	@echo "License: GPL-3.0"
	@echo "Copyright (C) 2025 Libero GNU/Linux Project"
	@echo "Maintainer: André Machado"
