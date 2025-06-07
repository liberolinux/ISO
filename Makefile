# Libero GNU/Linux - Admin CD i486 Makefile
# Based on Gentoo Linux
# Maintainer: André Machado
# License: GPL-3.0

DISTRO_NAME = Libero
VERSION = 1.1
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
    sys-block/parted \
	dev-util/dialog \
	net-misc/ntp \
	sys-apps/gptfdisk \
	sys-fs/cryptsetup \
	sys-fs/mdadm

# QEMU options
QEMU_MEMORY = 2048
QEMU_CPU = qemu32
QEMU_OPTS = -m $(QEMU_MEMORY) -cpu $(QEMU_CPU) -enable-kvm -boot d -netdev user,id=net0 -device e1000,netdev=net0

.PHONY: all check-deps download prepare chroot prepare-installer install-libero setup-grub squashfs build-iso debug-iso qemu qemu-hd clean help version

all: check-deps download prepare chroot prepare-installer install-libero setup-grub squashfs build-iso

check-deps:
	@echo "Checking for required dependencies..."

	@which bash >/dev/null || { echo "bash not found"; exit 1; }
	@which tar >/dev/null || { echo "tar not found"; exit 1; }
	@which wget >/dev/null || { echo "wget not found"; exit 1; }
	@which unzip >/dev/null || { echo "unzip not found"; exit 1; }
	@which sudo >/dev/null || { echo "sudo not found"; exit 1; }
	@test -x /usr/sbin/chroot || test -x /sbin/chroot || { echo "chroot not found"; exit 1; }
	@which mksquashfs >/dev/null || { echo "squashfs-tools not found"; exit 1; }
	@which grub-mkrescue >/dev/null || { echo "grub2 not found"; exit 1; }
	@which xorriso >/dev/null || { echo "xorriso not found"; exit 1; }
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
	sudo mount --bind /proc $(CHROOT_DIR)/proc
	sudo mount --bind /sys $(CHROOT_DIR)/sys

prepare-installer:
	@echo "Preparing gentoo-install for Libero..."
	sudo mkdir -p $(CHROOT_DIR)/opt/libero-installer
	@echo "Downloading and configuring libero-install..."
	cd $(WORK_DIR) && wget https://github.com/liberolinux/libero-install/archive/refs/heads/main.zip -O libero-install.zip || { echo "Failed to download libero-install"; exit 1; }
	cd $(WORK_DIR) && unzip -q libero-install.zip
	sudo cp -r $(WORK_DIR)/libero-install-main/* $(CHROOT_DIR)/opt/libero-installer/

install-libero:
	@echo "Installing Libero GNU/Linux required packages..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "emerge --sync"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'MAKEOPTS=\"-j$(shell nproc)\"' >> /etc/portage/make.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "emerge --update --deep --newuse @world"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /etc/portage/package.use && echo '>=sys-kernel/installkernel-50 dracut' >> /etc/portage/package.use/installkernel"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "emerge --ask $(LFS_PACKAGES)"

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

	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'nameserver 1.1.1.1' > /etc/resolv.conf"

	@echo "Configuring system for $(DISTRO_NAME)..."
	sudo sh -c 'echo "$(DISTRO_NAME) $(VERSION)" > $(CHROOT_DIR)/etc/gentoo-release'

	@echo "Configuring Live CD initramfs..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /etc/dracut.conf.d"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'add_dracutmodules+=\" dmsquash-live livenet network base dm \"' > /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'filesystems+=\" squashfs iso9660 overlay tmpfs \"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'drivers+=\" cdrom sr_mod loop dm-mod overlay \"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'compress=\"zstd\"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'hostonly=\"no\"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'hostonly_cmdline=\"no\"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'install_items+=\" /sbin/blkid /bin/findmnt /usr/bin/lsblk \"' >> /etc/dracut.conf.d/livecd.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "dracut --force --kver \$$(ls /lib/modules/) --no-hostonly --no-hostonly-cmdline --add 'dmsquash-live dm'"

	@echo "Creating live user and configuring auto-login..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "useradd -m -G audio,video,wheel -s /bin/bash libero || true"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'libero:libero' | chpasswd"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'root:libero' | chpasswd"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"

	sudo chroot $(CHROOT_DIR) /bin/bash -c "mkdir -p /etc/systemd/system/getty@tty1.service.d"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '[Unit]' > /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ConditionKernelCommandLine=!libero.mode=installer' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo '[Service]' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ExecStart=' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "echo 'ExecStart=-/sbin/agetty --autologin root --noclear %I \$$TERM' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"

	@echo "Setting up installation launcher..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "chmod +x /opt/libero-installer/install"
	sudo chroot $(CHROOT_DIR) /bin/bash -c "chmod +x /opt/libero-installer/configure"

	@echo "Enabling network services..."
	sudo chroot $(CHROOT_DIR) /bin/bash -c "systemctl enable dhcpcd.service"

	@echo "Creating systemd service for auto-installation..."

	sudo mkdir -p $(CHROOT_DIR)/etc/systemd/system
	sudo sh -c 'echo "[Unit]" > $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "Description=Libero Auto Installer" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "After=getty@tty1.service multi-user.target" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "Wants=getty@tty1.service" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "ConditionKernelCommandLine=libero.mode=installer" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "[Service]" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "Type=idle" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "WorkingDirectory=/opt/libero-installer" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "ExecStartPre=/opt/libero-installer/configure" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "ExecStart=/bin/bash -c \"/opt/libero-installer/install && echo '\''Press Enter to reboot...'\''; read && reboot\"" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "StandardInput=tty" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "StandardOutput=tty" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "TTYPath=/dev/tty1" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "Restart=no" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "[Install]" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'
	sudo sh -c 'echo "WantedBy=multi-user.target" >> $(CHROOT_DIR)/etc/systemd/system/libero-auto-install.service'

	@echo "Enabling libero installer service..."

	sudo chroot $(CHROOT_DIR) /bin/bash -c "systemctl enable libero-auto-install.service"

	@echo "Auto-installer setup complete (only runs in installer mode)."
	@echo "Auto-configure and installer setup complete (only runs in installer mode)."
	@echo "Libero GNU/Linux packages installed."

setup-grub:
	@echo "Setting up GRUB configuration..."

	sudo mkdir -p $(ISO_DIR)/boot/grub
	sudo sh -c 'echo "set default=0" > $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "set timeout=10" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod all_video" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod gzio" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod part_msdos" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod iso9660" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "insmod squash4" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "menuentry \"$(DISTRO_NAME) GNU/Linux $(VERSION) - Admin CD\" {" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    set root=(cd)" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    linux /boot/vmlinuz root=live:CDLABEL=LIBERO_11 rd.live.image rd.live.dir=/ rd.live.squashimg=image.squashfs libero.mode=admin quiet loglevel=7" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    initrd /boot/initrd" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "}" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "menuentry \"$(DISTRO_NAME) GNU/Linux $(VERSION) - Installer\" {" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    set root=(cd)" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    linux /boot/vmlinuz root=live:CDLABEL=LIBERO_11 rd.live.image rd.live.dir=/ rd.live.squashimg=image.squashfs libero.mode=installer quiet loglevel=7" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "    initrd /boot/initrd" >> $(ISO_DIR)/boot/grub/grub.cfg'
	sudo sh -c 'echo "}" >> $(ISO_DIR)/boot/grub/grub.cfg'

	@echo "GRUB setup complete."

squashfs:
	@echo "Creating squashfs image..."

	sudo mksquashfs $(CHROOT_DIR) $(ISO_DIR)/image.squashfs \
		-no-exports -comp zstd -Xcompression-level 22 \
		-e proc dev sys tmp var/tmp var/cache var/log/portage \
		-no-progress

	@echo "Squashfs image created at $(ISO_DIR)/image.squashfs"

build-iso:
	@echo "Creating ISO directory structure..."

	sudo mkdir -p $(ISO_DIR)/boot/grub
	sudo cp $(CHROOT_DIR)/boot/kernel-* $(ISO_DIR)/boot/vmlinuz
	sudo cp $(CHROOT_DIR)/boot/initramfs-* $(ISO_DIR)/boot/initrd

	@echo "Creating GRUB boot image..."

	if sudo grub-mkrescue --output=$(ISO_NAME) $(ISO_DIR) \
		--volid="LIBERO_11" \
		--product-name="$(DISTRO_NAME)" \
		--product-version="$(VERSION)"; then \
		echo "ISO created successfully with grub-mkrescue"; \
	else \
		echo "grub-mkrescue failed, trying manual GRUB setup..."; \
		sudo mkdir -p $(ISO_DIR)/boot/grub/i386-pc; \
		if [ -d /usr/lib/grub/i386-pc ] && [ -f /usr/lib/grub/i386-pc/moddep.lst ]; then \
			sudo cp -r /usr/lib/grub/i386-pc/* $(ISO_DIR)/boot/grub/i386-pc/; \
			sudo grub-mkimage -d /usr/lib/grub/i386-pc -o $(ISO_DIR)/boot/grub/core.img \
				-O i386-pc -p /boot/grub biosdisk iso9660 configfile normal search; \
			sudo sh -c 'cat /usr/lib/grub/i386-pc/cdboot.img $(ISO_DIR)/boot/grub/core.img > $(ISO_DIR)/boot/grub/eltorito.img'; \
		elif [ -d $(CHROOT_DIR)/usr/lib/grub/i386-pc ] && [ -f $(CHROOT_DIR)/usr/lib/grub/i386-pc/moddep.lst ]; then \
			sudo cp -r $(CHROOT_DIR)/usr/lib/grub/i386-pc/* $(ISO_DIR)/boot/grub/i386-pc/; \
			sudo grub-mkimage -d $(CHROOT_DIR)/usr/lib/grub/i386-pc -o $(ISO_DIR)/boot/grub/core.img \
				-O i386-pc -p /boot/grub biosdisk iso9660 configfile normal search; \
			sudo sh -c 'cat $(CHROOT_DIR)/usr/lib/grub/i386-pc/cdboot.img $(ISO_DIR)/boot/grub/core.img > $(ISO_DIR)/boot/grub/eltorito.img'; \
		else \
			echo "GRUB files not found, using xorriso without GRUB boot..."; \
		fi; \
		if [ -f $(ISO_DIR)/boot/grub/eltorito.img ]; then \
			sudo xorriso -as mkisofs -r -J -V "LIBERO_11" \
				-b boot/grub/eltorito.img -c boot/grub/boot.cat \
				-no-emul-boot -boot-load-size 4 -boot-info-table \
				-o $(ISO_NAME) $(ISO_DIR); \
		else \
			sudo xorriso -as mkisofs -r -J -V "LIBERO_11" \
				-o $(ISO_NAME) $(ISO_DIR); \
		fi; \
	fi

	@echo "ISO image created: $(ISO_NAME)"

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
	
	sudo umount $(CHROOT_DIR)/dev $(CHROOT_DIR)/proc $(CHROOT_DIR)/sys 2>/dev/null || true
	sudo rm -rf $(WORK_DIR) $(ISO_NAME) libero-hd.qcow2

help:
	@echo "Makefile for $(DISTRO_NAME) Admin CD"
	@echo "Usage:"
	@echo "  make all          - Build the entire Admin CD"
	@echo "  make check-deps   - Check for required dependencies"
	@echo "  make download     - Download Gentoo stage3 and portage snapshot"
	@echo "  make prepare      - Prepare the chroot environment"
	@echo "  make chroot       - Set up the chroot environment"
	@echo "  make prepare-installer - Download gentoo-install"
	@echo "  make install-libero - Install Libero GNU/Linux packages"
	@echo "  make setup-grub   - Set up GRUB configuration"
	@echo "  make squashfs     - Create Squashfs image"
	@echo "  make build-iso    - Build the ISO image"
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
