#!/bin/bash
set -euo pipefail

# terraform/scripts/qemu-manager.sh - QEMU VM Lifecycle Manager for Terraform
# Supported commands: start, stop, status, healthcheck

ACTION="${1:-help}"

# Defaults
VM_NAME="${VM_NAME:-yukios-vm}"
ISO_PATH="${ISO_PATH:-}"
DISK_IMAGE="${DISK_IMAGE:-$(pwd)/yukios-disk.qcow2}"
DISK_SIZE="${DISK_SIZE:-25G}"
RAM="${RAM:-4G}"
CORES="${CORES:-4}"
BOOT_MODE="${BOOT_MODE:-install}"
DISPLAY_TYPE="${DISPLAY_TYPE:-gtk}"
VNC_PORT="${VNC_PORT:-5900}"
SSH_HOST_PORT="${SSH_HOST_PORT:-2222}"
OVMF_CODE="${OVMF_CODE:-}"
ENABLE_KVM="${ENABLE_KVM:-true}"
WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1080}"
PID_FILE="${PID_FILE:-$(pwd)/logs/${VM_NAME}.pid}"
LOG_FILE="${LOG_FILE:-$(pwd)/logs/${VM_NAME}.log}"
QMP_SOCKET="${QMP_SOCKET:-$(pwd)/sockets/${VM_NAME}-qmp.sock}"
DELETE_DISK="${DELETE_DISK:-false}"

mkdir -p "$(dirname "$PID_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$QMP_SOCKET")"

# Locate OVMF firmware if not provided
find_ovmf() {
    if [ -n "$OVMF_CODE" ] && [ -f "$OVMF_CODE" ]; then
        echo "$OVMF_CODE"
        return
    fi
    for path in \
        "/usr/share/edk2/x64/OVMF_CODE.4m.fd" \
        "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd" \
        "/usr/share/ovmf/x64/OVMF_CODE.fd" \
        "/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd" \
        "/usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.4m.fd"
    do
        if [ -f "$path" ]; then
            echo "$path"
            return
        fi
    done
    echo ""
}

# Locate ISO if not provided
find_iso() {
    if [ -n "$ISO_PATH" ] && [ -f "$ISO_PATH" ]; then
        echo "$ISO_PATH"
        return
    fi
    local found
    found=$(ls -t ../out/*.iso 2>/dev/null | head -n 1 || true)
    if [ -n "$found" ] && [ -f "$found" ]; then
        echo "$(cd "$(dirname "$found")" && pwd)/$(basename "$found")"
        return
    fi
    found=$(ls -t out/*.iso 2>/dev/null | head -n 1 || true)
    if [ -n "$found" ] && [ -f "$found" ]; then
        echo "$(cd "$(dirname "$found")" && pwd)/$(basename "$found")"
        return
    fi
    echo ""
}

case "$ACTION" in
    start)
        echo "=== [YukiOS Terraform QEMU Manager: START] ==="
        echo "VM Name:      ${VM_NAME}"
        echo "Memory:       ${RAM}"
        echo "Cores:        ${CORES}"
        echo "Disk:         ${DISK_IMAGE} (${DISK_SIZE})"
        echo "Boot Mode:    ${BOOT_MODE}"
        echo "Display Type: ${DISPLAY_TYPE}"

        # 1. Check if already running
        if [ -f "$PID_FILE" ]; then
            OLD_PID=$(cat "$PID_FILE" 2>/dev/null || true)
            if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
                echo "VM '${VM_NAME}' is already running with PID ${OLD_PID}."
                exit 0
            else
                rm -f "$PID_FILE"
            fi
        fi

        # 2. Check or create virtual disk
        mkdir -p "$(dirname "$DISK_IMAGE")"
        if [ ! -f "$DISK_IMAGE" ]; then
            echo "Creating virtual disk (${DISK_SIZE}): ${DISK_IMAGE}..."
            qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
        else
            echo "Existing virtual disk detected: ${DISK_IMAGE}"
        fi

        # 3. Resolve Firmware
        FIRMWARE_PATH=$(find_ovmf)
        if [ -n "$FIRMWARE_PATH" ]; then
            echo "UEFI Firmware: ${FIRMWARE_PATH}"
        else
            echo "Warning: UEFI OVMF firmware not detected. Booting legacy BIOS."
        fi

        # 4. Resolve KVM Acceleration
        KVM_ARGS=()
        if [ "$ENABLE_KVM" = "true" ] && [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
            echo "Hardware Acceleration: KVM host CPU"
            KVM_ARGS=(-enable-kvm -cpu host)
        else
            echo "Hardware Acceleration: Disabled (TCG emulation)"
            KVM_ARGS=(-cpu max)
        fi

        # 5. Build QEMU arguments
        QEMU_CMD=(
            qemu-system-x86_64
            "${KVM_ARGS[@]}"
            -name "$VM_NAME"
            -m "$RAM"
            -smp "$CORES"
            -device "virtio-vga,xres=${WIDTH},yres=${HEIGHT}"
            -drive "file=${DISK_IMAGE},if=virtio,format=qcow2"
            -netdev "user,id=net0,hostfwd=tcp::${SSH_HOST_PORT}-:22"
            -device "virtio-net-pci,netdev=net0"
            -qmp "unix:${QMP_SOCKET},server,nowait"
        )

        if [ -n "$FIRMWARE_PATH" ]; then
            QEMU_CMD+=(-drive "if=pflash,format=raw,readonly=on,file=${FIRMWARE_PATH}")
        fi

        # Display handling
        VNC_DISPLAY_INDEX=$(( VNC_PORT - 5900 ))
        [ "$VNC_DISPLAY_INDEX" -lt 0 ] && VNC_DISPLAY_INDEX=0

        case "$DISPLAY_TYPE" in
            gtk)
                if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
                    QEMU_CMD+=(-display "gtk,zoom-to-fit=on" -vnc "127.0.0.1:${VNC_DISPLAY_INDEX}")
                else
                    echo "Notice: No GUI display detected. Falling back to VNC :${VNC_DISPLAY_INDEX}."
                    QEMU_CMD+=(-display none -vnc "127.0.0.1:${VNC_DISPLAY_INDEX}")
                fi
                ;;
            vnc)
                QEMU_CMD+=(-display none -vnc "127.0.0.1:${VNC_DISPLAY_INDEX}")
                ;;
            none)
                QEMU_CMD+=(-display none)
                ;;
            *)
                QEMU_CMD+=(-display "$DISPLAY_TYPE")
                ;;
        esac

        # Boot mode handling
        if [ "$BOOT_MODE" = "installed" ]; then
            echo "Booting from installed virtual hard drive..."
            QEMU_CMD+=(-boot c)
        else
            RESOLVED_ISO=$(find_iso)
            if [ -z "$RESOLVED_ISO" ] || [ ! -f "$RESOLVED_ISO" ]; then
                echo "Error: YukiOS ISO image not found. Please specify ISO_PATH or build it using ./scripts/build-iso.sh"
                exit 1
            fi
            echo "Booting from YukiOS Live ISO: ${RESOLVED_ISO}"
            QEMU_CMD+=(-cdrom "$RESOLVED_ISO" -boot d)
        fi

        # Clean old socket and pidfile if exists
        rm -f "$QMP_SOCKET" "$PID_FILE"
        QEMU_CMD+=(-pidfile "$PID_FILE")

        echo "Launching QEMU process in detached background session..."
        echo "Command: ${QEMU_CMD[*]}" >> "$LOG_FILE"
        setsid -f "${QEMU_CMD[@]}" >> "$LOG_FILE" 2>&1

        # Wait for PID file to be created and verify startup
        for _ in {1..10}; do
            if [ -f "$PID_FILE" ] && [ -s "$PID_FILE" ]; then
                VM_PID=$(cat "$PID_FILE")
                if [ -n "$VM_PID" ] && kill -0 "$VM_PID" 2>/dev/null; then
                    echo "YukiOS VM started successfully with PID: ${VM_PID}"
                    echo "SSH Forwarding: localhost:${SSH_HOST_PORT} -> guest:22"
                    echo "VNC Server:     127.0.0.1:${VNC_PORT}"
                    echo "Logs:           ${LOG_FILE}"
                    exit 0
                fi
            fi
            sleep 0.5
        done

        echo "Error: QEMU failed to start or write PID file. Last log entries:"
        tail -n 20 "$LOG_FILE" 2>/dev/null || true
        rm -f "$PID_FILE"
        exit 1
        ;;

    stop)
        PID_ARG="${2:-$PID_FILE}"
        DISK_ARG="${3:-$DISK_IMAGE}"
        DELETE_DISK_ARG="${4:-$DELETE_DISK}"

        echo "=== [YukiOS Terraform QEMU Manager: STOP] ==="
        if [ -f "$PID_ARG" ]; then
            TARGET_PID=$(cat "$PID_ARG" 2>/dev/null || true)
            if [ -n "$TARGET_PID" ] && kill -0 "$TARGET_PID" 2>/dev/null; then
                echo "Stopping QEMU VM (PID: ${TARGET_PID})..."
                kill "$TARGET_PID" 2>/dev/null || true
                
                # Wait for graceful termination
                WAIT_SECS=0
                while kill -0 "$TARGET_PID" 2>/dev/null && [ "$WAIT_SECS" -lt 10 ]; do
                    sleep 1
                    WAIT_SECS=$((WAIT_SECS + 1))
                done

                if kill -0 "$TARGET_PID" 2>/dev/null; then
                    echo "Forcing shutdown of PID ${TARGET_PID}..."
                    kill -9 "$TARGET_PID" 2>/dev/null || true
                fi
                echo "VM stopped."
            else
                echo "VM process is not running."
            fi
            rm -f "$PID_ARG"
        else
            echo "No PID file found at ${PID_ARG}. Nothing to stop."
        fi

        rm -f "$QMP_SOCKET"

        if [ "$DELETE_DISK_ARG" = "true" ] && [ -f "$DISK_ARG" ]; then
            echo "Deleting virtual disk as requested: ${DISK_ARG}"
            rm -f "$DISK_ARG"
        fi
        ;;

    status)
        if [ -f "$PID_FILE" ]; then
            TARGET_PID=$(cat "$PID_FILE" 2>/dev/null || true)
            if [ -n "$TARGET_PID" ] && kill -0 "$TARGET_PID" 2>/dev/null; then
                echo "running"
                exit 0
            fi
        fi
        echo "stopped"
        exit 1
        ;;

    healthcheck)
        if [ -f "$PID_FILE" ]; then
            TARGET_PID=$(cat "$PID_FILE" 2>/dev/null || true)
            if [ -n "$TARGET_PID" ] && kill -0 "$TARGET_PID" 2>/dev/null; then
                exit 0
            fi
        fi
        exit 1
        ;;

    *)
        echo "Usage: $0 {start|stop [pid_file] [disk_image] [delete_disk]|status|healthcheck}"
        exit 1
        ;;
esac
