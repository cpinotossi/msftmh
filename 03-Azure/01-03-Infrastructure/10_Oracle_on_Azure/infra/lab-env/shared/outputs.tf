# ===============================================================================
# Outputs - Shared Infrastructure
# ===============================================================================
# These outputs are consumed by the users/ project via terraform_remote_state.
# ===============================================================================

# ===============================================================================
# Compute Gallery
# ===============================================================================

output "image_id" {
  description = "ID of the Image Definition"
  value       = azurerm_shared_image.oracle_workshop.id
}

output "gallery_id" {
  description = "ID of the Compute Gallery"
  value       = azurerm_shared_image_gallery.gallery.id
}

output "gallery_name" {
  description = "Name of the Compute Gallery"
  value       = azurerm_shared_image_gallery.gallery.name
}

# ===============================================================================
# Shared ODAA VNets
# ===============================================================================

output "odaa_vnet_id" {
  description = "ID of the shared ODAA VNet"
  value       = azurerm_virtual_network.shared_odaa.id
}

output "odaa_vnet_name" {
  description = "Name of the shared ODAA VNet"
  value       = azurerm_virtual_network.shared_odaa.name
}

output "odaa_resource_group_name" {
  description = "Name of the shared ODAA resource group"
  value       = azurerm_resource_group.shared_odaa.name
}

output "odaa_subnet_id" {
  description = "ID of the shared ODAA delegated subnet"
  value       = azurerm_subnet.shared_odaa.id
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

output "resource_anchor_id" {
  description = "ID of the Oracle Resource Anchor"
  value       = azapi_resource.resource_anchor.id
}

# ===============================================================================
# Role Definition
# ===============================================================================

output "odaa_role_definition_resource_id" {
  description = "Resource ID of the Oracle Database Creator custom role"
  value       = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
}
