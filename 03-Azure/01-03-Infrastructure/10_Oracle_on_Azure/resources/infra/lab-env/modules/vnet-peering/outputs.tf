# ===============================================================================
# VNet Peering Module - Outputs
# ===============================================================================

output "vm_to_odaa_peering_id" {
  description = "The ID of the VM to ODAA VNet peering"
  value       = azurerm_virtual_network_peering.vm_to_odaa.id
}

output "odaa_to_vm_peering_id" {
  description = "The ID of the ODAA to VM VNet peering"
  value       = azurerm_virtual_network_peering.odaa_to_vm.id
}

output "vm_vnet_info" {
  description = "Information about the VM virtual network"
  value = {
    id             = var.vm_vnet_id
    name           = var.vm_vnet_name
    resource_group = var.vm_resource_group
  }
}

output "odaa_vnet_info" {
  description = "Information about the ODAA virtual network"
  value = {
    id             = var.odaa_vnet_id
    name           = var.odaa_vnet_name
    resource_group = var.odaa_resource_group
  }
}