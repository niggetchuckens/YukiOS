# terraform/main.tf - YukiOS Automated VM Deployment

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  runner_script = "${abspath(path.module)}/scripts/qemu-manager.sh"
  pid_file      = "${abspath(path.module)}/logs/${var.vm_name}.pid"
  log_file      = "${abspath(path.module)}/logs/${var.vm_name}.log"
  qmp_socket    = "${abspath(path.module)}/sockets/${var.vm_name}-qmp.sock"
  disk_image    = startswith(var.disk_image_path, "/") ? var.disk_image_path : "${abspath(path.module)}/${var.disk_image_path}"
}

resource "null_resource" "yukios_vm" {
  triggers = {
    runner_path = local.runner_script
    pid_file    = local.pid_file
    disk_image  = local.disk_image
    delete_disk = tostring(var.delete_disk_on_destroy)
    vm_name     = var.vm_name
    boot_mode   = var.boot_mode
    memory      = var.memory
    cpu_cores   = tostring(var.cpu_cores)
  }

  provisioner "local-exec" {
    command = "bash ${local.runner_script} start"
    environment = {
      VM_NAME          = var.vm_name
      ISO_PATH         = var.iso_path
      DISK_IMAGE       = local.disk_image
      DISK_SIZE        = var.disk_size
      RAM              = var.memory
      CORES            = tostring(var.cpu_cores)
      BOOT_MODE        = var.boot_mode
      DISPLAY_TYPE     = var.display_type
      VNC_PORT         = tostring(var.vnc_port)
      SSH_HOST_PORT    = tostring(var.ssh_host_port)
      OVMF_CODE        = var.uefi_firmware_path
      ENABLE_KVM       = tostring(var.enable_kvm)
      WIDTH            = tostring(var.resolution_width)
      HEIGHT           = tostring(var.resolution_height)
      PID_FILE         = local.pid_file
      LOG_FILE         = local.log_file
      QMP_SOCKET       = local.qmp_socket
      WAYLAND_DISPLAY  = coalesce(var.wayland_display, "wayland-1")
      DISPLAY          = coalesce(var.display, ":1")
      XDG_RUNTIME_DIR  = coalesce(var.xdg_runtime_dir, "/run/user/1000")
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${self.triggers.runner_path} stop ${self.triggers.pid_file} ${self.triggers.disk_image} ${self.triggers.delete_disk}"
  }
}
