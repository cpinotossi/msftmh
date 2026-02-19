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

output "user_index" {
  description = "Index of the user"
  value       = var.user_index
}
