# Libero GNU/Linux - Admin CD (i486)

<div align="center">

![Libero GNU/Linux](https://img.shields.io/badge/Libero-GNU%2FLinux-1f425f.svg)
![Architecture](https://img.shields.io/badge/arch-i486-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)
![License](https://img.shields.io/badge/license-GPL--3.0-orange.svg)
![Based on](https://img.shields.io/badge/based%20on-Gentoo%20Linux-purple.svg)

*A specialized live CD distribution for system administration and Gentoo installation*

[🏠 Homepage](https://libero.eu.org) • [📖 Documentation](#documentation) • [🚀 Quick Start](#quick-start) • [🤝 Contributing](#contributing)

</div>

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Requirements](#system-requirements)
- [Quick Start](#quick-start)
- [Build Process](#build-process)
- [Usage Modes](#usage-modes)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

Libero GNU/Linux Admin CD is a specialized live distribution based on Gentoo Linux, designed for system administration tasks and automated Gentoo installation. Built for the i486 architecture, it provides a complete bootable environment with dual-mode functionality.

### Key Highlights

- **Dual Boot Modes**: Admin mode for system maintenance, Installer mode for automated deployment
- **Gentoo-based**: Built on solid Gentoo Linux foundation with systemd
- **Modern Tools**: Includes latest system administration and installation utilities
- **Automated Installation**: Integrated gentoo-install framework for hands-off deployment
- **Legacy Support**: Optimized for i486 architecture and older hardware

## ✨ Features

### 🔧 System Administration Tools
- **Disk Management**: parted, gptfdisk, dosfstools
- **Network Tools**: dhcpcd, wpa_supplicant, ntp
- **Security**: cryptsetup, mdadm, sudo
- **System Utilities**: dialog, various diagnostic tools

### 📦 Installation Framework
- **Automated Installer**: [gentoo-install](https://github.com/oddlama/gentoo-install) integration
- **Interactive Configuration**: TUI-based setup wizard
- **Advanced Features**: LUKS encryption, LVM, RAID support
- **Systemd Integration**: Modern init system with service management

### 🚀 Boot Options
- **Admin Mode**: Full administrative environment with root access
- **Installer Mode**: Automated installation with configuration wizard
- **Live Environment**: RAM-based system with overlay support
- **Network Boot**: DHCP configuration and remote access capabilities

## 💻 System Requirements

### Minimum Requirements
- **CPU**: i486 or higher (32-bit x86)
- **RAM**: 256 MB (512 GB recommended)
- **Storage**: CD/DVD drive or USB port for booting
- **Network**: Ethernet or Wi-Fi for installation mode

### Build Requirements
- **Host OS**: Linux system with root access
- **Dependencies**: bash, tar, wget, sudo, chroot, squashfs-tools, grub2, xorriso, qemu
- **Storage**: ~10 GB free space for build process
- **Network**: Internet connection for downloading components

## 🚀 Quick Start

### Download Pre-built ISO
```bash
# Download the latest release
wget https://github.com/yourusername/libero-admincd/releases/latest/libero-admincd-i486-1.0.iso

# Verify checksum (if provided)
sha256sum libero-admincd-i486-1.0.iso
```

### Boot the ISO
1. **Burn to CD/DVD** or **write to USB drive**
2. **Boot from the media**
3. **Select boot mode** at GRUB menu:
   - "Libero GNU/Linux 1.0 - Admin CD" (maintenance mode)
   - "Libero GNU/Linux 1.0 - Installer" (installation mode)

### Test with QEMU
```bash
# Quick test
qemu-system-i386 -m 1024 -cdrom libero-admincd-i486-1.0.iso

# Test with virtual hard drive
qemu-img create -f qcow2 test-hd.qcow2 10G
qemu-system-i386 -m 1024 -hda test-hd.qcow2 -cdrom libero-admincd-i486-1.0.iso
```

## 🔨 Build Process

### 1. Check Dependencies
```bash
make check-deps
```

### 2. Complete Build
```bash
# Build everything (recommended)
make all
```

### 3. Step-by-Step Build
```bash
# Download Gentoo components
make download

# Prepare build environment
make prepare

# Set up chroot
make chroot

# Configure installer
make prepare-installer

# Install packages
make install-libero

# Configure bootloader
make setup-grub

# Create filesystem
make squashfs

# Build final ISO
make build-iso
```

### 4. Testing
```bash
# Debug ISO contents
make debug-iso

# Test in QEMU
make qemu

# Test with virtual hard drive
make qemu-hd
```

### 5. Cleanup
```bash
make clean
```

## 🎮 Usage Modes

### Admin Mode (`libero.mode=admin`)
- **Purpose**: System maintenance and recovery
- **Login**: Auto-login as root (password: `libero`)
- **Features**: Full system access, network configuration, diagnostic tools
- **Use Cases**: System recovery, disk management, network troubleshooting

### Installer Mode (`libero.mode=installer`)
- **Purpose**: Automated Gentoo installation
- **Process**: Automatic launch of configuration wizard
- **Features**: Interactive setup, encryption support, automated deployment
- **Use Cases**: Fresh installations, system deployment, automated setups

## 🛠 Development

### Project Structure
```
Libero_Installation_CD/
├── Makefile              # Main build configuration
├── README.md            # This file
├── work/                # Build directory (created during build)
│   ├── chroot/         # Gentoo chroot environment
│   ├── iso/            # ISO staging area
│   └── stage3/         # Gentoo stage3 files
└── libero-admincd-i486-1.0.iso  # Final ISO output
```

### Available Make Targets
```bash
make help                 # Show all available targets
make check-deps          # Verify build dependencies
make download            # Download Gentoo components
make prepare             # Prepare build environment
make chroot              # Set up chroot environment
make prepare-installer   # Configure gentoo-install
make install-libero      # Install system packages
make setup-grub          # Configure bootloader
make squashfs           # Create compressed filesystem
make build-iso          # Generate final ISO
make debug-iso          # Debug ISO contents
make qemu               # Test in QEMU
make qemu-hd            # Test with virtual hard drive
make clean              # Clean build environment
make version            # Show version information
```

### Customization

#### Adding Packages
Edit the `LFS_PACKAGES` variable in the Makefile:
```makefile
LFS_PACKAGES = \
    sys-boot/grub \
    sys-kernel/gentoo-kernel-bin \
    your-additional-package \
    another-package
```

#### Modifying Boot Parameters
Edit the GRUB configuration in the `setup-grub` target to add custom kernel parameters.

#### Custom Services
Add systemd services in the `install-libero` target for additional functionality.

## 🐛 Troubleshooting

### Common Issues

#### Build Fails During Package Installation
```bash
# Check internet connection
ping gentoo.org

# Verify Gentoo mirrors are accessible
make download

# Clean and retry
make clean
make all
```

#### ISO Won't Boot
```bash
# Verify ISO integrity
make debug-iso

# Check GRUB configuration
cat work/iso/boot/grub/grub.cfg

# Test in QEMU first
make qemu
```

#### Installer Mode Doesn't Start
- Ensure you selected the "Installer" option in GRUB
- Check that `libero.mode=installer` is in kernel parameters
- Verify systemd service is enabled: `systemctl status libero-auto-install`

### Build Environment Issues
```bash
# Check dependencies
make check-deps

# Verify permissions
sudo -v

# Check disk space
df -h

# Clean and restart
make clean
```

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues
- Use GitHub Issues for bug reports
- Include system information and build logs
- Provide steps to reproduce problems

### Code Contributions
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Documentation
- Improve README or inline documentation
- Add usage examples
- Translate documentation

### Testing
- Test on different hardware configurations
- Report compatibility issues
- Validate installation procedures

## 📚 Documentation

- **Homepage**: https://libero.eu.org
- **Gentoo Install Framework**: https://github.com/oddlama/gentoo-install
- **Gentoo Documentation**: https://wiki.gentoo.org
- **systemd Documentation**: https://systemd.io

## 📄 License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

```
Copyright (C) 2025 Libero GNU/Linux Project
Maintainer: André Machado

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

## 🙏 Acknowledgments

- **Gentoo Linux Project** - Base distribution and excellent documentation
- **oddlama** - gentoo-install framework
- **systemd Project** - Modern init system
- **GRUB Project** - Universal bootloader

---

<div align="center">

**Built with ❤️ by the Libero GNU/Linux Project**

*Empowering system administrators with reliable, modern tools*

</div>
