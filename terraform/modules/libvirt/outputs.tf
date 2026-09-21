# terraform/modules/libvirt/outputs.tf - Libvirt Module Outputs

output "domain_id" {
  description = "Libvirt Domain ID."
  value       = libvirt_domain.yukios.id
}

output "domain_name" {
  description = "Libvirt Domain Name."
  value       = libvirt_domain.yukios.name
}

output "root_volume_id" {
  description = "Root disk volume ID."
  value       = libvirt_volume.yukios_disk.id
}
