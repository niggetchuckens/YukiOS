# YukiOS

YukiOS is an advanced, performance-focused Arch Linux-based operating system distribution project featuring the **Calamares** graphical installer, a **KDE Plasma 6** desktop environment, optimized CachyOS x86_64-v3 repositories, BlackArch penetration testing tools, pre-installed productivity applications, and automated Infrastructure-as-Code (**Terraform**) deployment.

---

## Key Highlights

- **Graphical Installer**: Integrated [Calamares](https://calamares.io/) modular installer with a custom TokyoNight theme, brand assets, and multi-kernel initramfs generation.
- **Desktop Environment**: **KDE Plasma 6** + SDDM with Wayland session support, desktop shortcuts, and root GUI authorization via Xwayland.
- **Default Applications**:
  - **Brave Browser** (`brave-bin` via CachyOS)
  - **Discord** (`discord` via Arch Extra)
  - **Antigravity IDE** (`antigravity-ide` via custom local repository)
  - **Spotify** (`spotify` via custom local repository)
  - **Kitty** (`kitty`), pre-configured as the system-wide default terminal emulator
- **Multi-Repository Architecture**:
  - Arch Linux official repositories (`core`, `extra`, `multilib`)
  - **CachyOS** repositories (`cachyos-v3`, `cachyos-core-v3`, `cachyos-extra-v3`, `cachyos`) with CPU-optimized packages
  - **BlackArch** security and penetration testing repository
  - Out-of-the-box **yay** AUR helper
- **Dual Kernel Support**:
  - `linux-cachyos-lts` (performance-tuned LTS kernel as primary)
  - `linux` (official Arch kernel as fallback)
- **Infrastructure as Code & Virtualization**:
  - Standalone **Terraform** / **OpenTofu** engine for zero-configuration local VM deployment.
  - Native QEMU/KVM automation with UEFI OVMF firmware and 1080p display.
  - CLI management wrapper script (`scripts/manage-vm.sh`).

---

## Project Structure

```
YukiOS/
├── archiso/                    # Archiso Live ISO profile
│   └── profile/
│       ├── airootfs/           # Root filesystem overlay for Live ISO & target installation
│       │   ├── etc/calamares/  # Calamares installer configuration, modules & branding
│       │   ├── etc/sddm.conf.d/# SDDM autologin configuration
│       │   ├── etc/skel/       # User skeleton with Desktop application launchers
│       │   └── usr/local/bin/  # Helper scripts (calamares-autostart, yukios-target-cleanup)
│       ├── local-repo/         # Local pacman repository for prebuilt AUR packages
│       ├── packages.x86_64     # Live ISO & Calamares package manifest
│       ├── pacman.conf         # Archiso pacstrap repository definitions
│       └── profiledef.sh       # ISO metadata and filesystem permissions
├── scripts/                    # Automation & helper scripts
│   ├── build-iso.sh            # Automated ISO build script (with --clean and --run flags)
│   ├── manage-vm.sh            # Comprehensive CLI manager for the Terraform VM
│   └── run-qemu.sh             # Direct QEMU+KVM runner with UEFI OVMF support
├── terraform/                  # Infrastructure-as-Code VM automation
│   ├── main.tf                 # Terraform root module (detached QEMU engine)
│   ├── variables.tf            # Configurable VM parameters (RAM, CPU, disk, display)
│   ├── outputs.tf              # Connection strings, VNC endpoints, SSH forwards
│   ├── terraform.tfvars.example# Example variable customization file
│   ├── scripts/qemu-manager.sh # Detached process management engine
│   └── modules/libvirt/        # Alternative module for Libvirt / KVM server clusters
├── binaries/                   # Pre-compiled packages and build instructions
│   ├── built/apps/             # Local archive of built package archives
│   └── pre-compile-binaries.md # Guide for building PKGBUILDs with makepkg
├── configs/                    # Legacy / alternative Python CLI installer modules
│   └── installer.py            # CLI-based Arch Linux installer
├── BUGS_AND_FIXES.md           # Detailed bug tracking log (BUG-001 through BUG-012)
├── yukios-calamares-guide.md   # Architectural reference for Calamares on Archiso
├── todo.md                     # Roadmap and planned improvements
└── README.md                   # Project documentation
```

---

## Building the YukiOS Live ISO

### Prerequisites
Ensure your build host has `archiso`, `qemu-desktop`, and `edk2-ovmf` installed:
```bash
sudo pacman -S --needed archiso qemu-desktop edk2-ovmf
```

### Build Command
Compile the bootable Live ISO using the automated build script:
```bash
./scripts/build-iso.sh --clean
```

- Output is generated in the `out/` directory: `out/yukios-<date>-x86_64.iso`.
- Add `--run` to automatically boot the freshly compiled image in QEMU once the build succeeds:
  ```bash
  ./scripts/build-iso.sh --clean --run
  ```

---

## ISO Architecture & Sizing

The generated YukiOS ISO is approximately **3.9 GB**. The storage footprint is distributed as follows:

| Component | Size on ISO | Details |
|---|---|---|
| **Compressed Rootfs (`airootfs.sfs`)** | **~2.4 GB** | `xz`-compressed from an **8.0 GB** uncompressed rootfs containing KDE Plasma 6, Qt6 runtimes, hardware firmware, and heavy default apps: Antigravity IDE (721 MB), Brave Browser (462 MB), Spotify (370 MB), and Kitty (66 MB). |
| **Boot Images (`/arch/boot/`)** | **~724 MB** | Contains three full initramfs images (`linux-cachyos-lts`, `linux`, and fallback) plus kernel binaries. |
| **UEFI Partition (`efiboot.img`)** | **~727 MB** | A FAT image duplicate of the `/arch/boot/` files required by standard UEFI firmware to boot. |
| **Bootloaders & Metadata** | **~50 MB** | GRUB, Syslinux, and ISO filesystem metadata. |

---

## Testing & Virtual Machine Deployment

YukiOS provides multiple ways to test and deploy virtual machines:

### Method 1: The Unified VM Manager (`scripts/manage-vm.sh`)
The recommended way to manage the VM using Terraform without needing to write Terraform commands manually:

```bash
# Deploy and start installer VM in a GTK desktop window
./scripts/manage-vm.sh up

# Deploy headlessly with VNC server accessible at 127.0.0.1:5900
./scripts/manage-vm.sh up install vnc

# Boot the installed system directly from the virtual hard drive (post-install)
./scripts/manage-vm.sh up installed

# Check execution status and running PID
./scripts/manage-vm.sh status

# Follow QEMU execution logs in real time
./scripts/manage-vm.sh logs -f

# SSH into the running guest (forwarded to localhost:2222)
./scripts/manage-vm.sh ssh

# Launch local VNC client
./scripts/manage-vm.sh vnc

# Safely shut down the VM (preserves virtual disk)
./scripts/manage-vm.sh down
```

### Method 2: Native Terraform Commands
You can also interact directly with Terraform:

```bash
cd terraform
terraform init
terraform apply
```

To customize RAM, CPU cores, or display backend, create a `terraform.tfvars`:
```hcl
vm_name      = "yukios-dev"
memory       = "8G"
cpu_cores    = 6
display_type = "gtk"      # "gtk", "vnc", or "none"
boot_mode    = "install"  # "install" or "installed"
```

To destroy the VM:
```bash
terraform destroy
```
*(The virtual disk is preserved by default to prevent accidental data loss. Set `delete_disk_on_destroy = true` in `terraform.tfvars` if you wish to remove the disk image upon destroy).*

### Method 3: Direct QEMU Script
Run QEMU directly without Terraform:
```bash
# Boot Live ISO installer
./scripts/run-qemu.sh

# Boot installed system from the virtual disk
./scripts/run-qemu.sh "" installed
```

---

## Installation Walkthrough

1. **Boot into the Live Desktop**: The ISO automatically starts SDDM and logs in as `liveuser` into a KDE Plasma 6 desktop session.
2. **Calamares Installer**: The installer will launch automatically within a few seconds, or you can double-click **"Install YukiOS"** on the desktop.
3. **Partitioning**: Choose manual partitioning or erase disk. Calamares will format the EFI system partition and root partition.
4. **User & System Setup**: Create your user account and choose your locale/keyboard layout.
5. **System Finalization**: Calamares unpacks the system, compiles initramfs images for both kernels via `mkinitcpio -P`, initializes the Pacman keyring (`archlinux`, `cachyos`, `blackarch`), and purges live-only autologin services.
6. **Reboot**: Shut down the VM and boot with `boot_mode = "installed"` or `./scripts/manage-vm.sh up installed`.

---

## Documentation & Troubleshooting

- **[YukiOS Calamares Integration Guide](yukios-calamares-guide.md)**: Deep dive into the Calamares module sequence, configuration files, branding descriptors, and target system cleanup.
- **[Bugs & Fixes Log](BUGS_AND_FIXES.md)**: Detailed reports on bugs discovered and resolved during development (BUG-001 through BUG-012), including keyring initialization, missing repositories, kernel initramfs configuration, and Wayland root execution.
- **[Terraform Documentation](terraform/README.md)**: Full parameter reference, input variables, outputs, and instructions for the Libvirt cluster module.
- **[Pre-compiling Binaries Guide](binaries/pre-compile-binaries.md)**: Instructions for compiling AUR packages with `makepkg` and adding them to the local repository.

---

## Roadmap

Check [`todo.md`](todo.md) for tracked roadmap tasks and planned features:
- [x] Automatic local XAMPP configuration script.
- [x] Desktop environment selection.
- [x] `yay` AUR helper pre-installed.
- [x] Pre-compiled PortProton package integration.
- [x] BlackArch penetration testing repository.
- [x] CachyOS LTS kernel integration.
- [x] Calamares graphical installer with TokyoNight branding and KDE Plasma 6 Live ISO.
- [x] Virtualization tooling and automated Terraform deployment.
- [ ] Development language toolchains (Rust, Node.js, Go, Python).
- [ ] Additional developer IDE profiles and system customizers.
