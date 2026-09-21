# terraform/modules/libvirt/variables.tf - Libvirt Provider Input Variables

variable "libvirt_uri" {
  type        = string
  default     = "qemu:///session"
  description = "libvirt connection URI ('qemu:///session' for rootless user session, or 'qemu:///system' for system daemon)."
}

variable "vm_name" {
  type        = string
  default     = "yukios-libvirt-vm"
  description = "Unique name identifier for the domain/VM in libvirt."
}

variable "pool_name" {
  type        = string
  default     = "default"
  description = "Libvirt storage pool name where volumes will be created."
}

variable "iso_source_path" {
  type        = string
  description = "Path to the YukiOS Live ISO on the host."
}

variable "disk_size_bytes" {
  type        = number
  default     = 26843545600 # 25 GiB
  description = "Size of the virtual hard disk in bytes."
}

variable "memory_mb" {
  type        = number
  default     = 4096
  description = "RAM allocated to the VM in Megabytes."
}

variable "vcpu_count" {
  type        = number
  default     = 4
  description = "Number of virtual CPU cores."
}

variable "network_name" {
  type        = string
  default     = "default"
  description = "Libvirt network to attach the VM to."
}

variable "uefi_firmware" {
  type        = string
  default     = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
  description = "Path to UEFI OVMF firmware code file on the hypervisor."
}
