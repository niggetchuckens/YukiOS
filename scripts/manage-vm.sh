#!/bin/bash
set -euo pipefail

# scripts/manage-vm.sh - YukiOS Terraform Virtual Machine Manager
# Automates initialization, deployment, lifecycle management, and access for the YukiOS VM.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="${PROJECT_ROOT}/terraform"

# ANSI Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

usage() {
    echo -e "${BOLD}YukiOS Terraform Virtual Machine Manager${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC} $0 <command> [options]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${CYAN}up [mode] [display]${NC}   Deploy and start the VM via Terraform"
    echo -e "                         mode:    'install' (Live ISO, default) | 'installed' (virtual disk)"
    echo -e "                         display: 'gtk' (desktop GUI, default)  | 'vnc' (headless VNC) | 'none'"
    echo -e "  ${CYAN}down${NC}                  Stop and destroy the VM via Terraform (preserves virtual disk)"
    echo -e "  ${CYAN}restart [mode]${NC}        Restart the VM (runs down then up)"
    echo -e "  ${CYAN}status${NC}                Show the current execution status, PID, and assigned ports"
    echo -e "  ${CYAN}logs [-f]${NC}             Display VM logs (pass -f or --follow to tail live logs)"
    echo -e "  ${CYAN}ssh${NC}                   Connect to the guest via forwarded SSH (port 2222)"
    echo -e "  ${CYAN}vnc${NC}                   Show VNC connection info or launch vncviewer if available"
    echo -e "  ${CYAN}init${NC}                  Initialize or update Terraform providers"
    echo -e "  ${CYAN}plan${NC}                  Generate and display a Terraform execution plan"
    echo -e "  ${CYAN}help${NC}                  Display this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  $0 up                   # Start Live ISO installer in GTK desktop window"
    echo -e "  $0 up install vnc       # Start Live ISO headlessly with VNC at 127.0.0.1:5900"
    echo -e "  $0 up installed         # Boot installed system from virtual hard drive"
    echo -e "  $0 status               # Check whether the VM is running"
    echo -e "  $0 logs -f              # Follow QEMU execution logs"
    echo -e "  $0 ssh                  # SSH into liveuser@localhost:2222"
    echo -e "  $0 down                 # Safely shut down the VM"
}

check_terraform() {
    if ! command -v terraform &>/dev/null && ! command -v tofu &>/dev/null; then
        echo -e "${RED}Error: Neither 'terraform' nor 'tofu' command found in PATH.${NC}"
        echo "Please ensure Terraform or OpenTofu is installed."
        exit 1
    fi
}

get_tf_cmd() {
    if command -v terraform &>/dev/null; then
        echo "terraform"
    else
        echo "tofu"
    fi
}

ensure_initialized() {
    TF=$(get_tf_cmd)
    if [ ! -d "${TF_DIR}/.terraform" ]; then
        echo -e "${YELLOW}Terraform not initialized. Running 'terraform init'...${NC}"
        (cd "$TF_DIR" && "$TF" init)
    fi
}

CMD="${1:-help}"
shift || true

case "$CMD" in
    up|start)
        check_terraform
        ensure_initialized
        TF=$(get_tf_cmd)

        MODE="${1:-install}"
        DISPLAY_TYPE="${2:-gtk}"

        # If user passed --vnc or --gtk as first arg
        if [ "$MODE" = "vnc" ] || [ "$MODE" = "none" ] || [ "$MODE" = "gtk" ]; then
            DISPLAY_TYPE="$MODE"
            MODE="install"
        fi

        echo -e "${GREEN}==> Deploying YukiOS VM (${MODE} mode, display: ${DISPLAY_TYPE})...${NC}"
        (cd "$TF_DIR" && "$TF" apply -auto-approve \
            -var="boot_mode=${MODE}" \
            -var="display_type=${DISPLAY_TYPE}")
        ;;

    down|stop)
        check_terraform
        TF=$(get_tf_cmd)
        echo -e "${YELLOW}==> Stopping YukiOS VM...${NC}"
        (cd "$TF_DIR" && "$TF" destroy -auto-approve)
        ;;

    restart)
        check_terraform
        $0 down
        sleep 1
        $0 up "$@"
        ;;

    status)
        check_terraform
        TF=$(get_tf_cmd)
        PID_FILE="${TF_DIR}/logs/yukios-vm.pid"
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE" 2>/dev/null || true)
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                echo -e "${GREEN}● YukiOS VM is RUNNING (PID: ${PID})${NC}"
                (cd "$TF_DIR" && "$TF" output)
                exit 0
            fi
        fi
        echo -e "${RED}○ YukiOS VM is STOPPED${NC}"
        ;;

    logs)
        LOG_FILE="${TF_DIR}/logs/yukios-vm.log"
        if [ ! -f "$LOG_FILE" ]; then
            echo -e "${YELLOW}No log file found at ${LOG_FILE}.${NC}"
            exit 0
        fi
        if [[ "${1:-}" =~ ^(-f|--follow)$ ]]; then
            tail -f "$LOG_FILE"
        else
            tail -n 50 "$LOG_FILE"
        fi
        ;;

    ssh)
        echo -e "${CYAN}Connecting to YukiOS VM via SSH on port 2222...${NC}"
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 liveuser@localhost
        ;;

    vnc)
        VNC_ADDR="127.0.0.1:5900"
        echo -e "${CYAN}VNC Server Endpoint: ${VNC_ADDR}${NC}"
        for viewer in vncviewer remmina tiger-vnc gvncviewer; do
            if command -v "$viewer" &>/dev/null; then
                echo "Launching $viewer..."
                exec "$viewer" "$VNC_ADDR"
            fi
        done
        echo -e "${YELLOW}No local VNC viewer detected in PATH. Connect manually to: ${VNC_ADDR}${NC}"
        ;;

    init)
        check_terraform
        TF=$(get_tf_cmd)
        echo -e "${CYAN}==> Initializing Terraform in ${TF_DIR}...${NC}"
        (cd "$TF_DIR" && "$TF" init "$@")
        ;;

    plan)
        check_terraform
        ensure_initialized
        TF=$(get_tf_cmd)
        (cd "$TF_DIR" && "$TF" plan "$@")
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        echo -e "${RED}Unknown command: ${CMD}${NC}"
        echo ""
        usage
        exit 1
        ;;
esac
