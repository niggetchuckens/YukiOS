#!/bin/bash
set -euo pipefail

# scripts/build-iso.sh - Automated build script for YukiOS Calamares Live ISO

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROFILE_DIR="${PROJECT_ROOT}/archiso/profile"
OUT_DIR="${PROJECT_ROOT}/out"
WORK_DIR="/var/tmp/yukios-archiso-work"

echo "============================================="
echo "Building YukiOS Calamares Live ISO"
echo "============================================="
echo "Profile directory: ${PROFILE_DIR}"
echo "Output directory:  ${OUT_DIR}"
echo "Work directory:    ${WORK_DIR}"

if ! command -v mkarchiso &>/dev/null; then
    echo "Error: mkarchiso not found. Please install archiso package."
    exit 1
fi

mkdir -p "${OUT_DIR}"

CLEAN=false
RUN_VM=false
for arg in "$@"; do
    case "$arg" in
        --clean|-c) CLEAN=true ;;
        --run|-r) RUN_VM=true ;;
    esac
done

if [ "$CLEAN" = true ]; then
    echo "Cleaning previous work directory and old ISOs..."
    if command -v pkexec &>/dev/null; then
        pkexec rm -rf "${WORK_DIR}"
    else
        sudo rm -rf "${WORK_DIR}"
    fi
    rm -f "${OUT_DIR}"/*.iso
fi

# Run mkarchiso with elevated privileges
if command -v pkexec &>/dev/null; then
    pkexec mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"
else
    sudo mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"
fi

echo "============================================="
echo "Build complete!"
LATEST_ISO=$(ls -t "${OUT_DIR}"/*.iso 2>/dev/null | head -n 1 || true)
if [ -n "$LATEST_ISO" ]; then
    echo "Generated ISO: ${LATEST_ISO}"
    ls -lh "${LATEST_ISO}"
    echo ""
    if [ "$RUN_VM" = true ]; then
        echo "Auto-launching QEMU instance..."
        exec "${SCRIPT_DIR}/run-qemu.sh" "${LATEST_ISO}"
    else
        echo "To test this ISO in QEMU+KVM, run:"
        echo "  ./scripts/run-qemu.sh"
    fi
fi
echo "============================================="
