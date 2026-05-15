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

output "user_index" {
  description = "Index of the user"
  value       = var.user_index
}

