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

output "db_type" {
  description = "Type of database deployed (none, adb, basedb)"
  value       = var.db_type
}

# ===============================================================================
# ADB Outputs
# ===============================================================================

output "adb_id" {
  description = "ID of the Autonomous Database (null when db_type != 'adb')"
  value       = var.db_type == "adb" ? azurerm_oracle_autonomous_database.adb[0].id : null
}

output "adb_name" {
  description = "Name of the Autonomous Database (null when db_type != 'adb')"
  value       = var.db_type == "adb" ? azurerm_oracle_autonomous_database.adb[0].name : null
}

# ===============================================================================
# BaseDB Outputs
# ===============================================================================

output "exadata_infrastructure_id" {
  description = "ID of the Exadata Infrastructure (null when db_type != 'basedb')"
  value       = var.db_type == "basedb" ? azurerm_oracle_exadata_infrastructure.basedb[0].id : null
}

output "cloud_vm_cluster_id" {
  description = "ID of the Cloud VM Cluster (null when db_type != 'basedb')"
  value       = var.db_type == "basedb" ? azurerm_oracle_cloud_vm_cluster.basedb[0].id : null
}
