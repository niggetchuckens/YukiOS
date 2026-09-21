# YukiOS Development: Bugs & Fixes Log

This document tracks all bugs, anomalies, and runtime failures discovered during the development, building, and testing of the YukiOS Calamares ISO and installed environments.

---

## Index of Tracked Bugs

| ID | Title / Symptom | Component | Severity | Status |
|---|---|---|---|---|
| **BUG-001** | Desktop launcher warning: "Untrusted application launcher" | XFCE / Desktop | Low | **Resolved** |
| **BUG-002** | QEMU VM display resolution too small (800x600 / low-res) | QEMU / Xorg | Low | **Resolved** |
| **BUG-003** | Calamares unpack failure: `amd-ucode.img` does not exist | Calamares (`unpackfs`) | High | **Resolved** |
| **BUG-004** | Calamares does not launch automatically at live environment boot | Autostart / Live Session | Medium | **Resolved** |
| **BUG-005** | Pacstrap conflict: `calamares.desktop exists in filesystem` during ISO build | Archiso / Pacstrap | High | **Resolved** |
| **BUG-006** | System boot failure after install: `sh: can't access tty; job control turned off` | Mkinitcpio / Calamares / Initramfs | Critical | **Resolved** |
| **BUG-007** | Pacman keyring uninitialized / not writable (`keyring is not writable`, `required key missing`) | Pacman / GPG Keyring | High | **Resolved** |
| **BUG-008** | Missing BlackArch and CachyOS repositories on installed system | Pacman Configuration | High | **Resolved** |
| **BUG-009** | Missing AUR helper (`yay` not installed) | Package Management | Medium | **Resolved** |
| **BUG-010** | Missing CachyOS LTS kernel (`linux-cachyos-lts` not installed / not unpacked) | Kernel / Initcpio | High | **Resolved** |
| **BUG-011** | Calamares autostart failing in KDE Plasma due to `OnlyShowIn=XFCE;` | Autostart / Desktop Environment | Medium | **Resolved** |
| **BUG-012** | Calamares root GUI failure under KDE Plasma Wayland session | Wayland / Calamares / Qt | High | **Resolved** |

---

## Detailed Bug Reports

### BUG-001: Desktop launcher warning ("Untrusted application launcher")

- **Date Discovered**: 2026-09-21
- **Component**: XFCE 4 Desktop / Desktop Entries
- **Symptom**:
  Double-clicking `calamares.desktop` on the live user desktop prompted an untrusted executable dialog:
  `Exec=sudo -E calamares is untrusted`.
- **Root Cause**:
  XFCE and `exo-desktop-item-edit` enforce security checks on desktop shortcuts in `~/Desktop`. Files copied without explicit executable bits (`+x`) or without marking trust metadata in XFCE settings trigger a security prompt.
- **Fix Implemented**:
  1. Created `/usr/local/bin/trust-desktop-launchers` script that sets `chmod +x` on all `.desktop` files in `/etc/skel/Desktop` and `~/Desktop`.
  2. Created an autostart hook `/etc/xdg/autostart/trust-desktop.desktop` so desktop files are marked trusted on session initialization.
  3. Added explicit file permissions (`0:0:755`) to `profiledef.sh`.

---

### BUG-002: QEMU VM display resolution too small

- **Date Discovered**: 2026-09-21
- **Component**: QEMU runner script / Xorg display initialization
- **Symptom**:
  QEMU booted into a small resolution (800x600 / 1024x768), making Calamares installer buttons hard to reach or cut off.
- **Root Cause**:
  Default QEMU `-vga virtio` does not set default output resolutions unless explicitly specified with EDID parameters. Furthermore, XFCE did not automatically negotiate 1080p mode without xrandr intervention.
- **Fix Implemented**:
  1. Updated `scripts/run-qemu.sh` to use:
     ```bash
     -device virtio-vga,xres=1920,yres=1080 -display gtk,zoom-to-fit=on
     ```
  2. Added `xorg-xrandr` to `archiso/profile/packages.x86_64`.
  3. Added `/etc/skel/.xprofile` to execute `xrandr -s 1920x1080 || true` on X session start.

---

### BUG-003: Calamares unpack failure (`amd-ucode.img` does not exist)

- **Date Discovered**: 2026-09-21
- **Component**: Calamares `unpackfs` & `bootloader` modules
- **Symptom**:
  During installation in Calamares, the process aborted at the `unpackfs` step with the error:
  `'/run/archiso/bootmnt/arch/boot/amd-ucode.img' dont exist`.
- **Root Cause**:
  Legacy Calamares module configurations (inherited from older Archiso layouts like BlackArch) explicitly copied `/run/archiso/bootmnt/arch/boot/amd-ucode.img` and `intel-ucode.img`. In modern Archiso and Arch Linux kernel packaging, microcode images are generated dynamically or included into early initramfs by `mkinitcpio` via the `microcode` hook.
- **Fix Implemented**:
  1. Removed static microcode file unpack entries from `unpackfs.conf`.
  2. Added the `microcode` hook to `archiso/profile/airootfs/etc/calamares/modules/mkinitcpio.conf`.

---

### BUG-004: Calamares does not launch automatically at live environment boot

- **Date Discovered**: 2026-09-21
- **Component**: Live session startup
- **Symptom**:
  Booting the Live ISO opened an empty desktop session requiring the user to manually launch the Calamares installer.
- **Root Cause**:
  Missing XDG autostart entry for Calamares in `/etc/xdg/autostart/`.
- **Fix Implemented**:
  1. Created `/usr/local/bin/calamares-autostart` wrapper with a safety check:
     ```bash
     if [ ! -d /run/archiso ]; then
         exit 0
     fi
     exec sudo -E calamares
     ```
     This ensures Calamares starts automatically on live media but is completely ignored if booted on an installed disk.
  2. Added `/etc/xdg/autostart/calamares-autostart.desktop`.

---

### BUG-005: Pacstrap file collision during ISO build

- **Date Discovered**: 2026-09-21
- **Component**: Archiso `pacstrap` / `airootfs`
- **Symptom**:
  `build-iso.sh` failed during the `pacstrap` phase with:
  ```
  error: failed to commit transaction (conflicting files)
  calamares: /usr/share/applications/calamares.desktop exists in filesystem
  ```
- **Root Cause**:
  Both the official `calamares` package from Arch Linux repositories and the custom files in `archiso/profile/airootfs/usr/share/applications/calamares.desktop` provided the same file path.
- **Fix Implemented**:
  1. Removed `archiso/profile/airootfs/usr/share/applications/calamares.desktop` so the package repository provides the canonical application entry.
  2. Maintained desktop launch configuration through `/etc/skel/Desktop/calamares.desktop`.

---

### BUG-006: Target system boot failure (`sh: can't access tty; job control turned off`)

- **Date Discovered**: 2026-09-21
- **Component**: Mkinitcpio / Calamares (`unpackfs`, `shellprocess`, `initcpio`) / Initramfs
- **Symptom**:
  After installing YukiOS via Calamares to a disk (`test-vm-disk.qcow2`), rebooting the VM dropped into an initramfs emergency shell:
  ```
  sh: can't access tty; job control turned off
  [rootfs /]#
  ```
- **Root Cause**:
  1. **Live initramfs copy**: `unpackfs.conf` included an entry copying `/run/archiso/bootmnt/arch/boot/x86_64/initramfs-linux.img` directly to `/boot/initramfs-linux.img`. This put the live Archiso initramfs onto the target partition.
  2. **Archiso hook contamination**: Modern Archiso configures `/etc/mkinitcpio.conf.d/archiso.conf` (containing `HOOKS=(... archiso archiso_loop_mnt ...)`) and `/etc/mkinitcpio.d/linux.preset` (configuring `PRESETS=('archiso')` pointing to `archiso.conf`). When `airootfs.sfs` was unpacked to the target root, these live-only configs remained in place.
  3. **Failed initramfs generation**: When Calamares ran `initcpio` (`mkinitcpio -p linux`), it picked up the `archiso` preset from `linux.preset` and the hooks from `archiso.conf`.
  4. **Boot time failure**: Upon boot, the initramfs `archiso` hook ran looking for the Archiso boot media/label (`YUKIOS_...`). Because the target is an installed hard disk with standard partitions, the hook timed out and dropped to the Busybox emergency shell with `job control turned off`.
  5. **Schema key error in `initcpiocfg.conf`**: Used `path:` instead of `source: "/etc/calamares/modules/mkinitcpio.conf"`.
- **Fix Implemented**:
  1. **Created target preset**: Added `archiso/profile/airootfs/etc/mkinitcpio.d/linux-target.preset` specifying standard `PRESETS=('default' 'fallback')`, `ALL_config='/etc/mkinitcpio.conf'`, and `ALL_kver='/boot/vmlinuz-linux'`.
  2. **Prevented live initramfs copy**: Removed `initramfs-linux.img` from `unpackfs.conf` unpack list (only `vmlinuz-linux` is copied).
  3. **Excluded live configs in unpackfs**: Added `exclude` patterns in `unpackfs.conf` for `archiso.conf`, `linux.preset`, live autologins, and live systemd services.
  4. **Target cleanup via `shellprocess`**: Created `/usr/local/bin/yukios-target-cleanup` and Calamares `shellprocess.conf` running right before `initcpiocfg` and `initcpio` in `settings.conf`. The script purges `archiso.conf`, replaces `linux.preset` with `linux-target.preset`, removes live autologin/services, and deletes installer launchers.
  5. **Fixed `initcpiocfg.conf`**: Corrected key from `path:` to `source: "/etc/calamares/modules/mkinitcpio.conf"`.
  6. **Added `removeuser`**: Added Calamares's `removeuser` module to the execution sequence to ensure `liveuser` is purged from the target system.

---

### BUG-007: Pacman keyring uninitialized / not writable (`keyring is not writable`, `required key missing from keyring`)

- **Date Discovered**: 2026-09-21
- **Component**: Pacman / GPG Keyring initialization
- **Symptom**:
  Running `pacman -S ...` or installing packages on the installed system failed with:
  ```
  error: keyring is not writable
  error: required key missing from keyring
  error: failed to commit transaction (unexpected error)
  ```
- **Root Cause**:
  1. In Archiso, `/etc/pacman.d/gnupg` is mounted on a `tmpfs` at live boot and populated dynamically by `pacman-init.service`. The persistent root filesystem image (`airootfs.sfs`) therefore contains an empty, uninitialized `/etc/pacman.d/gnupg` directory.
  2. When Calamares unpacked `airootfs.sfs`, no persistent keyring was initialized on the installed disk.
  3. When `pacman` attempted to verify packages from third-party repositories without their public keys imported, GPG attempted an on-the-fly import into the uninitialized/unwritable keyring and aborted.
- **Fix Implemented**:
  1. Updated `/usr/local/bin/yukios-target-cleanup` to initialize the pacman keyring (`pacman-key --init`), populate trusted keys (`pacman-key --populate archlinux cachyos blackarch`), and set proper permissions (`chmod 755 /etc/pacman.d/gnupg`, `chmod 644` on database/key files).
  2. Created `/etc/systemd/system/yukios-pacman-init.service` with `ConditionPathExists=!/etc/pacman.d/gnupg/trustdb.gpg` so that if the keyring is ever missing on first boot, it is automatically initialized and populated in the background.
  3. Installed `cachyos-keyring` and `blackarch-keyring` packages into `packages.x86_64` so their public keys are physically present in `/usr/share/pacman/keyrings/`.

---

### BUG-008: Missing BlackArch and CachyOS repositories on installed system

- **Date Discovered**: 2026-09-21
- **Component**: Pacman Configuration (`/etc/pacman.conf`)
- **Symptom**:
  The installed YukiOS system did not have the BlackArch or CachyOS repositories configured in `/etc/pacman.conf`.
- **Root Cause**:
  `archiso/profile/pacman.conf` was only used by `mkarchiso` during the ISO creation `pacstrap` phase on the host. Inside `airootfs`, `archiso/profile/airootfs/etc/pacman.conf` was missing, causing the system to default to Arch Linux's standard `pacman.conf` containing only `[core]`, `[extra]`, and `[multilib]`.
- **Fix Implemented**:
  1. Created `/etc/pacman.conf` in `archiso/profile/airootfs/etc/pacman.conf` with `Color`, `ILoveCandy`, `ParallelDownloads = 5`, `Architecture = auto x86_64_v3`, and repository definitions for `[core]`, `[extra]`, `[multilib]`, `[cachyos-v3]`, `[cachyos-core-v3]`, `[cachyos-extra-v3]`, `[cachyos]`, and `[blackarch]`.
  2. Configured `SigLevel = Optional TrustAll` for CachyOS and BlackArch to prevent signing mismatches.
  3. Included `cachyos-mirrorlist`, `cachyos-v3-mirrorlist`, and `blackarch-mirrorlist` packages in `packages.x86_64`.

---

### BUG-009: Missing AUR helper (`yay` not installed)

- **Date Discovered**: 2026-09-21
- **Component**: Package Management / AUR Tooling
- **Symptom**:
  The `yay` command was not found in the installed YukiOS system.
- **Root Cause**:
  `yay` was not included in `archiso/profile/packages.x86_64`.
- **Fix Implemented**:
  1. Added `yay` to `archiso/profile/packages.x86_64`.
  2. Enabled `[cachyos]` and `[blackarch]` repositories (which package and maintain `yay`) with `Architecture = auto x86_64_v3` in `archiso/profile/pacman.conf` so `mkarchiso` installs `yay` directly into the system image.

---

### BUG-010: Missing CachyOS LTS kernel (`linux-cachyos-lts` not installed / not unpacked)

- **Date Discovered**: 2026-09-21
- **Component**: Kernel / Mkinitcpio / Calamares `unpackfs`
- **Symptom**:
  The installed YukiOS system only had the stock `linux` kernel; `linux-cachyos-lts` was missing.
- **Root Cause**:
  `packages.x86_64` only listed `linux`. Additionally, `unpackfs.conf` only unpacked `vmlinuz-linux`, and `initcpio.conf` was hardcoded to `kernel: linux`.
- **Fix Implemented**:
  1. Added `linux-cachyos-lts` and `linux-cachyos-lts-headers` to `packages.x86_64`.
  2. Updated `unpackfs.conf` to extract both `/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-cachyos-lts` and `vmlinuz-linux` to `/boot/`.
  3. Updated `initcpio.conf` with `kernel: all` so Calamares executes `mkinitcpio -P`, building initramfs images for both `linux-cachyos-lts` and `linux`.

---

### BUG-011: Calamares autostart failing in KDE Plasma due to `OnlyShowIn=XFCE;`

- **Date Discovered**: 2026-09-21
- **Component**: Autostart / Desktop Environment Migration
- **Symptom**:
  Calamares installer does not start automatically when booting into the KDE Plasma Live environment.
- **Root Cause**:
  `calamares-autostart.desktop` contained the desktop specification directive `OnlyShowIn=XFCE;`. When switching the live environment from XFCE to KDE Plasma 6, the XDG desktop autostart manager ignored the file.
- **Fix Implemented**:
  Removed `OnlyShowIn=XFCE;` from `/etc/xdg/autostart/calamares-autostart.desktop` so the autostart launcher executes under any desktop environment (including KDE Plasma).

---

### BUG-012: Calamares root GUI failure under KDE Plasma Wayland session

- **Date Discovered**: 2026-09-21
- **Component**: Wayland / Calamares / Qt Platform Abstraction
- **Symptom**:
  When Calamares is launched with root privileges (`sudo -E calamares`) inside a KDE Plasma Wayland session, Qt may fail with `XDG_RUNTIME_DIR not owned by root` or refuse connection to the Wayland compositor.
- **Root Cause**:
  Root GUI applications under Wayland require permission to access the user session display. Wayland compositors prohibit root clients from attaching directly to user Wayland sockets without specialized authorization.
- **Fix Implemented**:
  1. Updated `/usr/local/bin/calamares-autostart` and `/usr/local/bin/yukios-calamares` to execute `xhost +si:localuser:root` (authorizing root access to Xwayland).
  2. Forced Qt to use the Xwayland platform plugin by exporting `QT_QPA_PLATFORM=xcb` when launching Calamares.
