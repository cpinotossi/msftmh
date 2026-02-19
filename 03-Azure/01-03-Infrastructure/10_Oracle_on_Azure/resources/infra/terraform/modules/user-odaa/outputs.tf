# ===============================================================================
# User ODAA Module - Outputs
# ===============================================================================

output "resource_group_name" {
  description = "Name of the ODAA resource group"
  value       = azurerm_resource_group.odaa.name
}

output "resource_group_id" {
  description = "ID of the ODAA resource group"
  value       = azurerm_resource_group.odaa.id
}

output "vnet_id" {
  description = "ID of the ODAA VNet"
  value       = azurerm_virtual_network.odaa.id
}

output "vnet_name" {
  description = "Name of the ODAA VNet"
  value       = azurerm_virtual_network.odaa.name
}

output "subnet_id" {
  description = "ID of the ODAA delegated subnet"
  value       = azurerm_subnet.odaa.id
}

output "subnet_name" {
  description = "Name of the ODAA delegated subnet"
  value       = azurerm_subnet.odaa.name
}

output "user_index" {
  description = "Index of the user"
  value       = var.user_index
}
