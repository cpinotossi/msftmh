# ===============================================================================
# Hub-Spoke Peering Module - Outputs
# ===============================================================================

output "hub_to_spoke_peering_id" {
  description = "ID of the hub-to-spoke peering"
  value       = azurerm_virtual_network_peering.hub_to_spoke.id
}

output "spoke_to_hub_peering_id" {
  description = "ID of the spoke-to-hub peering"
  value       = azurerm_virtual_network_peering.spoke_to_hub.id
}

output "route_table_id" {
  description = "ID of the spoke route table"
  value       = azurerm_route_table.spoke_to_hub.id
}

output "route_table_association_id" {
  description = "ID of the route table association"
  value       = azurerm_subnet_route_table_association.spoke.id
}
