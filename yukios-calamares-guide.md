# YukiOS Calamares Live ISO Integration Guide

Welcome to the definitive guide on integrating the **Calamares** graphical installer into your YukiOS Live ISO. Calamares is a modular, distribution-agnostic installer framework used by many major Linux distributions (such as Manjaro, EndeavourOS, Debian Live, and KDE Neon). 

This guide outlines the architecture, configuration, branding, security rules, and testing workflow used to provide a seamless graphical installation experience for YukiOS users.

---

## 1. Prerequisites and Live ISO Base

YukiOS builds its bootable live ISO media using `archiso` (`mkarchiso`). The live ISO environment includes:
*   **Desktop Environment**: KDE Plasma 6 with SDDM autologin for `liveuser`.
*   **Default Terminal**: Kitty (`kitty`), configured as system-wide default terminal emulator.
*   **Default Applications**:
    *   **Brave Browser** (`brave-bin` via CachyOS)
    *   **Discord** (`discord` via Arch Extra)
    *   **Antigravity IDE** (`antigravity-ide` via custom YukiOS local repo)
    *   **Spotify** (`spotify` via custom YukiOS local repo)
*   **Qt6 libraries**: `qt6-base`, `qt6-declarative`, `qt6-svg`, `qt6-wayland`.
*   **Polkit & Security**: `polkit-kde-agent` and `polkit-qt6`.
*   **KPMcore**: KDE Partition Manager core (required for disk partitioning).
*   **Calamares**: Modern graphical installer framework.
*   **System tools**: `arch-install-scripts`, `grub`, `efibootmgr`, `dosfstools`, `e2fsprogs`, `btrfs-progs`, `xfsprogs`, `mtools`.

> [!IMPORTANT]
> The `calamares` package and all desktop environment components are installed *within* the Live ISO environment via `archiso/profile/packages.x86_64`, not on the host building the ISO.

---

## 2. Archiso & Calamares Architecture

The Calamares installer configuration resides in `/etc/calamares/` inside the ISO's root filesystem overlay (`archiso/profile/airootfs/`):

| Directory / File | Purpose |
| :--- | :--- |
| `airootfs/etc/calamares/settings.conf` | The master configuration file. Controls the module sequence and branding selection. |
| `airootfs/etc/calamares/branding/yukios/` | Contains branding descriptors, logo, icon, welcome banner, QSS styles, and QML slideshow. |
| `airootfs/etc/calamares/modules/` | Contains specific `.conf` files for individual modules (partitioning, unpacking, bootloader, users, packages). |
| `airootfs/usr/local/bin/calamares-autostart` | Autostart script that launches Calamares upon Live ISO desktop boot (Wayland & X11 compatible). |
| `profiledef.sh` (`file_permissions`) | Configures desktop launchers in `/etc/skel/Desktop/` with `0:0:755` permissions for instant execution in KDE Plasma. |

---

## 3. Master Configuration: `settings.conf`

The `settings.conf` file dictates the flow of the installer:

```yaml
# /etc/calamares/settings.conf
---
modules-search: [ /usr/lib/calamares/modules, local ]

instances:
- module:   welcome
  id:       welcome
  config:   welcome.conf

- module:   partition
  id:       partition
  config:   partition.conf

- module:   mount
  id:       mount
  config:   mount.conf

- module:   unpackfs
  id:       unpackfs
  config:   unpackfs.conf

- module:   machineid
  id:       machineid
  config:   machineid.conf

- module:   fstab
  id:       fstab
  config:   fstab.conf

- module:   locale
  id:       locale
  config:   locale.conf

- module:   localecfg
  id:       localecfg
  config:   localecfg.conf

- module:   hwclock
  id:       hwclock
  config:   hwclock.conf

- module:   keyboard
  id:       keyboard
  config:   keyboard.conf

- module:   packages
  id:       packages
  config:   packages.conf

- module:   users
  id:       users
  config:   users.conf

- module:   networkcfg
  id:       networkcfg
  config:   networkcfg.conf

- module:   displaymanager
  id:       displaymanager
  config:   displaymanager.conf

- module:   services-systemd
  id:       services-systemd
  config:   services-systemd.conf

- module:   shellprocess
  id:       shellprocess
  config:   shellprocess.conf

- module:   initcpiocfg
  id:       initcpiocfg
  config:   initcpiocfg.conf

- module:   initcpio
  id:       initcpio
  config:   initcpio.conf

- module:   grubcfg
  id:       grubcfg
  config:   grubcfg.conf

- module:   bootloader
  id:       bootloader
  config:   bootloader.conf

- module:   removeuser
  id:       removeuser
  config:   removeuser.conf

- module:   umount
  id:       umount
  config:   umount.conf

sequence:
- show:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - summary

- exec:
  - partition
  - mount
  - unpackfs
  - machineid
  - fstab
  - locale
  - localecfg
  - hwclock
  - keyboard
  - users
  - displaymanager
  - networkcfg
  - services-systemd
  - shellprocess
  - initcpiocfg
  - initcpio
  - grubcfg
  - bootloader
  - packages
  - removeuser
  - umount

- show:
  - finished

branding: yukios
prompt-install: true
dont-chroot: false
```

---

## 4. Branding YukiOS

The branding files reside in `/etc/calamares/branding/yukios/`.

### `branding.desc`
```yaml
---
componentName: yukios
welcomeStyleCalamares: false
welcomeExpandingLogo: true
windowExpanding: normal
windowSize: 800px,520px
windowPlacement: center

strings:
    productName:         YukiOS
    shortProductName:    YukiOS
    version:             1.0 (Genesis)
    shortVersion:        1.0
    versionedName:       YukiOS 1.0
    shortVersionedName:  YukiOS 1.0
    bootloaderEntryName: YukiOS
    productUrl:          https://github.com/niggetchuckens/YukiOS
    supportUrl:          https://github.com/niggetchuckens/YukiOS/issues
    knownIssuesUrl:      https://github.com/niggetchuckens/YukiOS/issues
    releaseNotesUrl:     https://github.com/niggetchuckens/YukiOS

images:
    productLogo:         "logo.png"
    productIcon:         "icon.png"
    productWelcome:      "welcome.png"

style:
   sidebarBackground:    "#1A1B26"
   sidebarText:          "#A9B1D6"
   sidebarTextSelect:    "#7AA2F7"
   sidebarTextHighlight: "#BB9AF7"

slideshow:               "show.qml"
slideshowAPI: 2
```

---

## 5. Essential Module Configurations

### File Extraction (`unpackfs.conf`)
Transfers the SquashFS root filesystem image and kernel to the target partition, while excluding live-media specific configurations:

```yaml
# /etc/calamares/modules/unpackfs.conf
---
unpack:
    - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
      sourcefs: squashfs
      destination: "/"
      exclude:
        - "/etc/sudoers.d/*"
        - "/etc/mkinitcpio.conf.d/archiso.conf"
        - "/etc/mkinitcpio.d/linux.preset"
        - "/etc/systemd/system/getty@tty1.service.d/autologin.conf"
        - "/etc/lightdm/lightdm.conf.d/autologin.conf"
        - "/etc/systemd/system/pacman-init.service"
        - "/etc/systemd/system/choose-mirror.service"
        - "/etc/systemd/system/livecd-alsa-unmuter.service"
        - "/etc/systemd/system/livecd-talk.service"
        - "/etc/systemd/system/etc-pacman.d-gnupg.mount"
        - "/etc/systemd/journald.conf.d/volatile-storage.conf"
        - "/etc/systemd/resolved.conf.d/archiso.conf"
        - "/etc/systemd/logind.conf.d/do-not-suspend.conf"
        - "/etc/ssh/sshd_config.d/10-archiso.conf"
        - "/etc/xdg/autostart/calamares-autostart.desktop"
        - "/etc/xdg/autostart/trust-desktop.desktop"
      weight: 160

    - source: "/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-cachyos-lts"
      sourcefs: file
      destination: "/boot/vmlinuz-linux-cachyos-lts"
      weight: 5

    - source: "/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
      sourcefs: file
      destination: "/boot/vmlinuz-linux"
      weight: 5
```

> [!IMPORTANT]
> **Live Initramfs vs. Target Initramfs**: Never unpack the live ISO's `initramfs-linux.img` onto the target system. The live image contains the `archiso` hook which searches for ISO media and fails when booting from a hard drive (`sh: can't access tty; job control turned off`). The target initramfs is freshly generated during installation by Calamares's `initcpio` module.

### Target Cleanup & Preset Switch (`shellprocess.conf`)
Runs `/usr/local/bin/yukios-target-cleanup` inside the target system chroot right before `initcpiocfg` and `initcpio`:
1. Removes `/etc/mkinitcpio.conf.d/archiso.conf`.
2. Renames `/etc/mkinitcpio.d/linux-target.preset` to `/etc/mkinitcpio.d/linux.preset`.
3. Purges live autologin configurations and live-only systemd services.
4. Removes installer autostarts and desktop shortcuts.

```yaml
# /etc/calamares/modules/shellprocess.conf
---
dontChroot: false
timeout: 60
script:
    - "-/usr/local/bin/yukios-target-cleanup"
```

### Target Initramfs Configuration (`initcpiocfg.conf`)
Specifies the template `/etc/calamares/modules/mkinitcpio.conf` used by Calamares to configure `/etc/mkinitcpio.conf` on the target system:

```yaml
# /etc/calamares/modules/initcpiocfg.conf
---
source: "/etc/calamares/modules/mkinitcpio.conf"
```

### Multi-Kernel Initramfs Generation (`initcpio.conf`)
Calamares builds initramfs images for all installed kernels (both `linux-cachyos-lts` and `linux`):

```yaml
# /etc/calamares/modules/initcpio.conf
---
kernel: all
be_unsafe: false
```

### System Pacman & Keyring Configuration
YukiOS provides `/etc/pacman.conf` preconfigured with `Color`, `ILoveCandy`, `ParallelDownloads = 5`, `Architecture = auto x86_64_v3`, and third-party repositories:
- **CachyOS**: `[cachyos-v3]`, `[cachyos-core-v3]`, `[cachyos-extra-v3]`, `[cachyos]`
- **BlackArch**: `[blackarch]`
- **AUR Helper**: `yay` is pre-installed out of the box in `/usr/bin/yay`.

The keyring initialization is managed via [`yukios-target-cleanup`](file:///home/hime/code/YukiOS/archiso/profile/airootfs/usr/local/bin/yukios-target-cleanup) (`pacman-key --init` and `pacman-key --populate archlinux cachyos blackarch`) with fallback service [`yukios-pacman-init.service`](file:///home/hime/code/YukiOS/archiso/profile/airootfs/etc/systemd/system/yukios-pacman-init.service) ensuring `/etc/pacman.d/gnupg` is always populated and writable.

### Bootloader (`bootloader.conf`)
Configures GRUB and UEFI entries:

```yaml
# /etc/calamares/modules/bootloader.conf
---
efiBootLoader: "grub"

kernelSearchPath: "/usr/lib/modules"
kernelName: "vmlinuz"
timeout: "10"

bootloaderEntryName: "YukiOS"

grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
grubProbe: "grub-probe"
efiBootMgr: "efibootmgr"
installEFIFallback: true
```

### Users (`users.conf`)
```yaml
# /etc/calamares/modules/users.conf
---
defaultGroups:
    - lp
    - power
    - video
    - network
    - storage
    - wheel
    - audio
    - sys
    - optical
    - scanner
    - rfkill

autologinGroup:             autologin
doAutologin:                false
sudoersGroup:               wheel
setRootPassword:            true
doReusePassword:            false
allowWeakPasswords:         true
allowWeakPasswordsDefault:  false

userShell: /bin/bash
avatarFilePath: ~/.face
setHostname: EtcFile
writeHostsFile: true
```

### Post-Install Cleanup (`packages.conf`)
Removes installer and live-CD packages from the newly installed target:

```yaml
# /etc/calamares/modules/packages.conf
---
backend: pacman
skip_if_no_internet: true
update_db: false
update_system: false
pacman:
    num_retries: 0
    disable_download_timeout: false
    needed_only: false

operations:
  - try_remove:
    - calamares
    - ckbcomp
    - kpmcore
    - mkinitcpio-archiso
    - arch-install-scripts
```

---

## 6. Live Desktop, Security & Autostart

### KDE Plasma 6 & SDDM Session Management
- **Display Manager**: SDDM manages the graphical login. In the Live ISO, autologin is configured via `/etc/sddm.conf.d/autologin.conf` to boot directly into `liveuser` using the Wayland session (`Session=plasma`).
- **Target Clean-Up**: `/etc/sddm.conf.d/autologin.conf` is explicitly excluded during installation and cleaned by `yukios-target-cleanup` so that the installed system presents a standard login screen for the user created in Calamares.

### Kitty as System-Wide Default Terminal Emulator
- Configured in `/etc/xdg/kdeglobals`:
  ```ini
  [General]
  TerminalApplication=kitty
  TerminalService=kitty.desktop
  ```
- Symlink `/usr/local/bin/x-terminal-emulator -> /usr/bin/kitty`.
- Set `TERMINAL=kitty` in `/etc/environment`.

### Pre-Installed Default Applications
The following applications are bundled directly into the ISO root filesystem:
- **Brave Web Browser** (`brave-bin`)
- **Discord** (`discord`)
- **Antigravity IDE** (`antigravity-ide`)
- **Spotify Client** (`spotify`)
- **Kitty Terminal** (`kitty`)

Desktop shortcuts for each application are pre-populated in `/etc/skel/Desktop/` and marked executable in `profiledef.sh`.

### Automatic Startup of Calamares on Live Boot
To automatically welcome users with the installer without requiring manual desktop clicks:
1. Script [`/usr/local/bin/calamares-autostart`](file:///home/hime/code/YukiOS/archiso/profile/airootfs/usr/local/bin/calamares-autostart):
   ```bash
   #!/bin/bash
   if [ -d /run/archiso ]; then
       sleep 3
       if command -v xhost &>/dev/null; then
           xhost +si:localuser:root 2>/dev/null || xhost + 2>/dev/null || true
       fi
       exec sudo -E calamares
   fi
   ```
2. Autostart desktop file in [`/etc/xdg/autostart/calamares-autostart.desktop`](file:///home/hime/code/YukiOS/archiso/profile/airootfs/etc/xdg/autostart/calamares-autostart.desktop).
3. The `[ -d /run/archiso ]` guard ensures Calamares **only auto-starts in live ISO sessions** and will never run at startup on the installed system.

### Display Resolution Management
- **Guest VM Auto-Resolution**: [`/etc/skel/.xprofile`](file:///home/hime/code/YukiOS/archiso/profile/airootfs/etc/skel/.xprofile) uses `xrandr` to automatically step up resolution to 1920x1080 if supported (under X11), and KDE Wayland handles dynamic display resizing natively via DRM/KMS.
- **QEMU Virtual Display**: `scripts/run-qemu.sh` configures `-device virtio-vga,xres=1920,yres=1080 -display gtk,zoom-to-fit=on`.

---

## 7. Building & Testing

### 1. Building the ISO
Run the build script with root privileges (uses `pkexec`):
```bash
./scripts/build-iso.sh --clean
```
Outputs the bootable ISO into the `out/` directory (e.g., `out/yukios-<date>-x86_64.iso`).

### 2. Testing in QEMU + KVM
```bash
./scripts/run-qemu.sh
```
- Provisions a 25GB virtual target drive (`test-vm-disk.qcow2`).
- Attaches the Live ISO as CD-ROM and boots in UEFI mode via OVMF.
- To boot the installed system directly from the virtual drive after running the installer:
  ```bash
  ./scripts/run-qemu.sh "" installed
  ```

---

## 8. Troubleshooting & Bug Log

All bugs encountered during development, installation, and VM deployment are tracked with root cause analysis and resolution steps in [BUGS_AND_FIXES.md](file:///home/hime/code/YukiOS/BUGS_AND_FIXES.md).

Key issues resolved:
- **Untrusted Desktop Launcher**: Solved via `trust-desktop-launchers` and executable file permissions.
- **QEMU Resolution**: Solved via `virtio-vga` resolution parameters and `.xprofile` with `xrandr`.
- **Missing `amd-ucode.img`**: Solved by relying on modern `mkinitcpio` microcode hooks instead of legacy file copies.
- **Calamares Autostart**: Solved via `/etc/xdg/autostart/calamares-autostart.desktop` with `/run/archiso` safety guard.
- **Pacstrap Collision**: Solved by removing duplicate desktop file from `airootfs`.
- **Initramfs `job control turned off` on Target Boot**: Solved by excluding live-only `archiso.conf` and `linux.preset`, running `yukios-target-cleanup` before `initcpio`, and providing `linux-target.preset` for clean installed kernel initramfs generation.
