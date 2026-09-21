#!/bin/bash
set -euo pipefail

# scripts/run-qemu.sh - Test YukiOS Calamares Live ISO in QEMU+KVM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUT_DIR="${PROJECT_ROOT}/out"
DISK_IMAGE="${PROJECT_ROOT}/test-vm-disk.qcow2"
DISK_SIZE="25G"
RAM="4G"
CORES="4"

# 1. Locate the ISO
ISO_PATH="${1:-}"
if [ -z "$ISO_PATH" ]; then
    # Find latest iso in out directory
    ISO_PATH=$(ls -t "${OUT_DIR}"/*.iso 2>/dev/null | head -n 1 || true)
fi

MODE="${2:-install}"  # "install" or "installed"

# 2. Check OVMF firmware
OVMF_CODE=""
for path in \
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd" \
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd" \
    "/usr/share/ovmf/x64/OVMF_CODE.fd"
do
    if [ -f "$path" ]; then
        OVMF_CODE="$path"
        break
    fi
done

if [ -z "$OVMF_CODE" ]; then
    echo "Warning: OVMF UEFI firmware not found. Installing edk2-ovmf is recommended."
fi

# 3. Create virtual hard drive if not present
if [ ! -f "$DISK_IMAGE" ]; then
    echo "Creating virtual test hard drive (${DISK_SIZE}): ${DISK_IMAGE}..."
    qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
fi

# 4. Check KVM support
KVM_FLAG=""
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_FLAG="-enable-kvm -cpu host"
    echo "KVM acceleration enabled."
else
    KVM_FLAG="-cpu max"
    echo "KVM not accessible; running with TCG software emulation."
fi

WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1080}"

# 5. Build QEMU arguments
QEMU_ARGS=(
    qemu-system-x86_64
    $KVM_FLAG
    -m "$RAM"
    -smp "$CORES"
    -device "virtio-vga,xres=${WIDTH},yres=${HEIGHT}"
    -display gtk,zoom-to-fit=on
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0
    -drive "file=${DISK_IMAGE},if=virtio,format=qcow2"
)

if [ -n "$OVMF_CODE" ]; then
    QEMU_ARGS+=(-drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}")
fi

if [ "$MODE" = "installed" ]; then
    echo "Booting installed YukiOS system from ${DISK_IMAGE}..."
    QEMU_ARGS+=(-boot c)
else
    if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
        echo "Error: No ISO found. Please run ./scripts/build-iso.sh first or pass ISO path as argument:"
        echo "  $0 /path/to/yukios.iso"
        exit 1
    fi
    echo "Booting YukiOS Live ISO: ${ISO_PATH}"
    echo "Target test disk: ${DISK_IMAGE}"
    QEMU_ARGS+=(-cdrom "$ISO_PATH" -boot d)
fi

echo "Launching QEMU..."
exec "${QEMU_ARGS[@]}"
