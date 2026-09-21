# YukiOS Terraform Automated VM Deployment

This directory provides infrastructure-as-code automation using **Terraform** (or **OpenTofu**) to provision, configure, and manage YukiOS virtual machines automatically.

---

## 1. Architecture Overview

Terraform manages the complete lifecycle of the YukiOS VM:
1. **Automated Resource Discovery**: Automatically detects the latest YukiOS ISO built in `../out/` and locates system UEFI OVMF firmware.
2. **Virtual Storage Provisioning**: Dynamically creates a 25GB `qcow2` virtual hard drive formatted for VirtIO block storage.
3. **Hardware Acceleration**: Automatically leverages `/dev/kvm` hardware CPU virtualization (with automatic fallback to TCG emulation).
4. **Display Flexibility**:
   - **GTK Desktop GUI** (`display_type = "gtk"`): Opens a native, responsive window on your active X11/Wayland desktop session.
   - **Headless VNC** (`display_type = "vnc"`): Runs headlessly, exposing a VNC server on `127.0.0.1:5900`.
   - **Headless** (`display_type = "none"`): Runs purely headless with SSH port forwarding.
5. **Networking & SSH**: Forwards host TCP port `2222` directly to guest port `22` for easy remote access.
6. **Graceful Teardown**: Upon running `terraform destroy`, sends ACPI/SIGTERM signals for a clean shutdown and preserves the virtual hard drive unless configured otherwise.

---

## 2. Quick Start

You can manage the VM either using the provided CLI helper script or native Terraform commands.

### Option A: Using the CLI Wrapper Script (Recommended)
From the repository root:
```bash
./scripts/manage-vm.sh up                 # Start installer VM (GTK desktop window)
./scripts/manage-vm.sh up install vnc     # Start headlessly with VNC (127.0.0.1:5900)
./scripts/manage-vm.sh status             # Check VM status and PID
./scripts/manage-vm.sh logs -f            # Follow QEMU execution logs
./scripts/manage-vm.sh down               # Gracefully stop the VM
```

### Option B: Using Native Terraform Commands
```bash
cd terraform
terraform init
```

### Step 2: Deploy the YukiOS Virtual Machine
```bash
terraform apply
```
Type `yes` when prompted. Terraform will:
- Detect the newest `out/yukios-*.iso`.
- Initialize `yukios-disk.qcow2`.
- Launch the QEMU process in the background.
- Display connection endpoints and management commands.

---

## 3. Configuration & Customization

To customize parameters, copy the example configuration:
```bash
cp terraform.tfvars.example terraform.tfvars
```

### Key Configuration Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `vm_name` | string | `"yukios-vm"` | Identifier for the VM, logs, and sockets. |
| `iso_path` | string | `""` (auto-detected) | Explicit path to the YukiOS Live ISO. |
| `disk_image_path` | string | `"yukios-disk.qcow2"` | Path to the target virtual hard disk. |
| `disk_size` | string | `"25G"` | Size of the virtual disk. |
| `memory` | string | `"4G"` | RAM allocated to the VM. |
| `cpu_cores` | number | `4` | Number of vCPUs. |
| `boot_mode` | string | `"install"` | `"install"` (boot Live ISO) or `"installed"` (boot installed hard drive). |
| `display_type` | string | `"gtk"` | `"gtk"` (GUI window), `"vnc"` (headless VNC), or `"none"`. |
| `vnc_port` | number | `5900` | Port for the local VNC server. |
| `ssh_host_port` | number | `2222` | Host port forwarded to guest SSH (port 22). |
| `enable_kvm` | bool | `true` | Enable KVM acceleration. |
| `delete_disk_on_destroy` | bool | `false` | Set to `true` to delete disk on `terraform destroy`. |

---

## 4. Booting the Installed System

Once you complete installation inside the VM using the **Calamares** installer:
1. Stop the current installer VM:
   ```bash
   terraform destroy
   ```
2. Switch `boot_mode` to `"installed"` in `terraform.tfvars`:
   ```hcl
   boot_mode = "installed"
   ```
3. Boot the installed system directly from the virtual hard drive:
   ```bash
   terraform apply
   ```

---

## 5. Monitoring & Interacting with the VM

- **View Live Logs**:
  ```bash
  tail -f logs/yukios-vm.log
  ```
- **Connect via VNC**:
  ```bash
  vncviewer 127.0.0.1:5900
  ```
- **SSH into Guest**:
  ```bash
  ssh -p 2222 liveuser@localhost
  ```
- **QMP Socket Control**:
  ```bash
  socat - UNIX-CONNECT:sockets/yukios-vm-qmp.sock
  ```

---

## 6. Libvirt / KVM Cluster Provider Module

For server environments or libvirt clusters, a dedicated module using the `dmacvicar/libvirt` provider is available in [`modules/libvirt/`](modules/libvirt/).
