# terraform/outputs.tf - YukiOS Virtual Machine Outputs

output "vm_name" {
  description = "The assigned name of the YukiOS virtual machine."
  value       = var.vm_name
}

output "status" {
  description = "Execution status of the VM."
  value       = "deployed and running"
  depends_on  = [null_resource.yukios_vm]
}

output "disk_image" {
  description = "Absolute path to the virtual disk image."
  value       = local.disk_image
}

output "disk_size" {
  description = "Allocated virtual disk capacity."
  value       = var.disk_size
}

output "memory" {
  description = "Allocated system RAM."
  value       = var.memory
}

output "cpu_cores" {
  description = "Allocated CPU cores."
  value       = var.cpu_cores
}

output "boot_mode" {
  description = "Active boot mode ('install' or 'installed')."
  value       = var.boot_mode
}

output "display_type" {
  description = "Active display backend ('gtk', 'vnc', or 'none')."
  value       = var.display_type
}

output "vnc_endpoint" {
  description = "Connection endpoint for VNC clients."
  value       = "127.0.0.1:${var.vnc_port}"
}

output "ssh_connection" {
  description = "SSH connection string for accessing the running guest."
  value       = "ssh -p ${var.ssh_host_port} liveuser@localhost"
}

output "log_file" {
  description = "File path containing QEMU runtime stdout and stderr logs."
  value       = local.log_file
}

output "pid_file" {
  description = "File path containing the QEMU process PID."
  value       = local.pid_file
}

output "qmp_socket" {
  description = "Unix domain socket path for QEMU Machine Protocol (QMP) control."
  value       = local.qmp_socket
}

output "instructions" {
  description = "Quick commands to interact with the running VM."
  value       = <<-EOT
    To check the VM logs:
      tail -f ${local.log_file}

    To connect via VNC (if VNC client is installed):
      vncviewer 127.0.0.1:${var.vnc_port}

    To SSH into the Live session (once network is initialized):
      ssh -p ${var.ssh_host_port} liveuser@localhost

    To stop and tear down the VM:
      terraform destroy
  EOT
}
