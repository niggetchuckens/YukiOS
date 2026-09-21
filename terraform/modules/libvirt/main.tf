# terraform/modules/libvirt/main.tf - Libvirt Provider YukiOS VM

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.6"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

# ISO installer volume
resource "libvirt_volume" "yukios_iso" {
  name   = "${var.vm_name}-install.iso"
  pool   = var.pool_name
  source = var.iso_source_path
  format = "raw"
}

# Target hard drive volume
resource "libvirt_volume" "yukios_disk" {
  name   = "${var.vm_name}-root.qcow2"
  pool   = var.pool_name
  size   = var.disk_size_bytes
  format = "qcow2"
}

# Libvirt domain definition
resource "libvirt_domain" "yukios" {
  name   = var.vm_name
  memory = var.memory_mb
  vcpu   = var.vcpu_count

  firmware = var.uefi_firmware

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.yukios_disk.id
    scsi      = false
  }

  disk {
    volume_id = libvirt_volume.yukios_iso.id
    scsi      = false
  }

  network_interface {
    network_name   = var.network_name
    wait_for_lease = false
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  video {
    type = "virtio"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}
