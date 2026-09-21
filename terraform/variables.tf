# terraform/variables.tf - YukiOS Virtual Machine Input Variables

variable "vm_name" {
  type        = string
  default     = "yukios-vm"
  description = "Unique name identifier for the YukiOS virtual machine."
}

variable "iso_path" {
  type        = string
  default     = ""
  description = "Absolute or relative path to the YukiOS Live ISO. If omitted, automatically discovers the newest ISO in out/."
}

variable "disk_image_path" {
  type        = string
  default     = "yukios-disk.qcow2"
  description = "Path to the target virtual hard disk image (qcow2 format)."
}

variable "disk_size" {
  type        = string
  default     = "25G"
  description = "Size of the virtual hard drive (e.g. '25G', '40G')."
}

variable "memory" {
  type        = string
  default     = "4G"
  description = "RAM allocated to the virtual machine (e.g. '4G', '8G')."
}

variable "cpu_cores" {
  type        = number
  default     = 4
  description = "Number of CPU cores assigned to the virtual machine."
}

variable "boot_mode" {
  type        = string
  default     = "install"
  description = "Boot mode: 'install' (boots from Live ISO with target disk attached) or 'installed' (boots directly from virtual disk)."
  validation {
    condition     = contains(["install", "installed"], var.boot_mode)
    error_message = "boot_mode must be either 'install' or 'installed'."
  }
}

variable "display_type" {
  type        = string
  default     = "gtk"
  description = "Display backend: 'gtk' (native desktop window), 'vnc' (headless VNC server), or 'none' (headless)."
  validation {
    condition     = contains(["gtk", "vnc", "none"], var.display_type)
    error_message = "display_type must be one of: 'gtk', 'vnc', 'none'."
  }
}

variable "vnc_port" {
  type        = number
  default     = 5900
  description = "TCP port on localhost for the VNC server when VNC or GTK is active."
}

variable "ssh_host_port" {
  type        = number
  default     = 2222
  description = "Host TCP port forwarded to the guest SSH service (port 22)."
}

variable "uefi_firmware_path" {
  type        = string
  default     = ""
  description = "Explicit path to OVMF_CODE.fd UEFI firmware. If left empty, common system paths will be auto-detected."
}

variable "enable_kvm" {
  type        = bool
  default     = true
  description = "Enable KVM hardware acceleration (auto-falls back to TCG emulation if KVM is unavailable)."
}

variable "resolution_width" {
  type        = number
  default     = 1920
  description = "Virtual display resolution width in pixels."
}

variable "resolution_height" {
  type        = number
  default     = 1080
  description = "Virtual display resolution height in pixels."
}

variable "delete_disk_on_destroy" {
  type        = bool
  default     = false
  description = "Set to true to delete the virtual hard disk image upon 'terraform destroy'. Defaults to false to prevent data loss."
}

variable "wayland_display" {
  type        = string
  default     = ""
  description = "Explicit WAYLAND_DISPLAY variable. Defaults to host environment if empty."
}

variable "display" {
  type        = string
  default     = ""
  description = "Explicit DISPLAY variable. Defaults to host environment if empty."
}

variable "xdg_runtime_dir" {
  type        = string
  default     = ""
  description = "Explicit XDG_RUNTIME_DIR variable. Defaults to host environment if empty."
}
