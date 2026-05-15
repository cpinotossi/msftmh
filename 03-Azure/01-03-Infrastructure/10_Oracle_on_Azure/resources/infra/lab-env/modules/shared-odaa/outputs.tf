# ===============================================================================
# Shared ODAA Module - Outputs
# ===============================================================================

output "resource_group_name" {
  description = "Name of the shared ODAA resource group"
  value       = azurerm_resource_group.shared_odaa.name
}

output "resource_group_id" {
  description = "ID of the shared ODAA resource group"
  value       = azurerm_resource_group.shared_odaa.id
}

output "vnet_id" {
  description = "ID of the shared ODAA VNet"
  value       = azurerm_virtual_network.shared_odaa.id
}

output "vnet_name" {
  description = "Name of the shared ODAA VNet"
  value       = azurerm_virtual_network.shared_odaa.name
}

output "subnet_id" {
  description = "ID of the shared ODAA delegated subnet"
  value       = azurerm_subnet.shared_odaa.id
}

output "subnet_name" {
  description = "Name of the shared ODAA delegated subnet"
  value       = azurerm_subnet.shared_odaa.name
}

output "basedb_vnet_id" {
  description = "ID of the shared BaseDB VNet"
  value       = azurerm_virtual_network.basedb.id
}

output "basedb_vnet_name" {
  description = "Name of the shared BaseDB VNet"
  value       = azurerm_virtual_network.basedb.name
}

output "basedb_subnet_id" {
  description = "ID of the shared BaseDB delegated subnet"
  value       = azurerm_subnet.basedb.id
}

output "basedb_subnet_name" {
  description = "Name of the shared BaseDB delegated subnet"
  value       = azurerm_subnet.basedb.name
}

output "resource_anchor_id" {
  description = "ID of the Oracle Resource Anchor"
  value       = azapi_resource.resource_anchor.id
}
