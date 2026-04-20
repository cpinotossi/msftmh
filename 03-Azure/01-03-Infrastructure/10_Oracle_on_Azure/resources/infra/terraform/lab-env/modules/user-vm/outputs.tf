# ===============================================================================
# User VM Module - Outputs
# ===============================================================================

output "resource_group_name" {
  description = "Name of the VM resource group"
  value       = azurerm_resource_group.vm.name
}

output "resource_group_id" {
  description = "ID of the VM resource group"
  value       = azurerm_resource_group.vm.id
}

output "vnet_id" {
  description = "ID of the VM VNet"
  value       = azurerm_virtual_network.vm.id
}

output "vnet_name" {
  description = "Name of the VM VNet"
  value       = azurerm_virtual_network.vm.name
}

output "subnet_id" {
  description = "ID of the VM subnet"
  value       = azurerm_subnet.vm.id
}

output "vm_id" {
  description = "ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "private_ip_address" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "public_ip_address" {
  description = "Public IP address of the VM (if created)"
  value       = var.create_public_ip ? azurerm_public_ip.vm[0].ip_address : null
}

output "bastion_host_name" {
  description = "Name of the Bastion host (if created)"
  value       = var.enable_bastion ? azurerm_bastion_host.vm[0].name : null
}

output "bastion_public_ip_address" {
  description = "Public IP address of Bastion host (if created)"
  value       = var.enable_bastion ? azurerm_public_ip.bastion[0].ip_address : null
}

output "user_index" {
  description = "Index of the user"
  value       = var.user_index
}

output "dns_zone_name" {
  description = "Private DNS Zone name (if created/linked)"
  value       = var.create_dns_link ? var.dns_zone_name : null
}

output "dns_zone_resource_group" {
  description = "Resource group of the Private DNS Zone (if created/linked)"
  value       = var.create_dns_link ? (var.dns_zone_resource_group != null && trimspace(var.dns_zone_resource_group) != "" ? var.dns_zone_resource_group : azurerm_resource_group.vm.name) : null
}

output "dns_zone_id" {
  description = "Private DNS Zone ID (only when created in this module)"
  value       = var.create_dns_link && (var.dns_zone_resource_group == null || trimspace(var.dns_zone_resource_group) == "") ? azurerm_private_dns_zone.odaa[0].id : null
}
