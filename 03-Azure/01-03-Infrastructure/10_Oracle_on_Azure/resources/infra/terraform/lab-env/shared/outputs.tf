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
  value       = module.shared.image_id
}

output "gallery_id" {
  description = "ID of the Compute Gallery"
  value       = module.shared.gallery_id
}

output "gallery_name" {
  description = "Name of the Compute Gallery"
  value       = module.shared.gallery_name
}

# ===============================================================================
# Shared ODAA VNets
# ===============================================================================

output "odaa_vnet_id" {
  description = "ID of the shared ODAA VNet"
  value       = module.shared_odaa.vnet_id
}

output "odaa_vnet_name" {
  description = "Name of the shared ODAA VNet"
  value       = module.shared_odaa.vnet_name
}

output "odaa_resource_group_name" {
  description = "Name of the shared ODAA resource group"
  value       = module.shared_odaa.resource_group_name
}

output "odaa_subnet_id" {
  description = "ID of the shared ODAA delegated subnet"
  value       = module.shared_odaa.subnet_id
}

output "basedb_vnet_id" {
  description = "ID of the shared BaseDB VNet"
  value       = module.shared_odaa.basedb_vnet_id
}

output "basedb_vnet_name" {
  description = "Name of the shared BaseDB VNet"
  value       = module.shared_odaa.basedb_vnet_name
}

output "basedb_subnet_id" {
  description = "ID of the shared BaseDB delegated subnet"
  value       = module.shared_odaa.basedb_subnet_id
}

output "resource_anchor_id" {
  description = "ID of the Oracle Resource Anchor"
  value       = module.shared_odaa.resource_anchor_id
}

# ===============================================================================
# Role Definition
# ===============================================================================

output "odaa_role_definition_resource_id" {
  description = "Resource ID of the Oracle Database Creator custom role"
  value       = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
}
