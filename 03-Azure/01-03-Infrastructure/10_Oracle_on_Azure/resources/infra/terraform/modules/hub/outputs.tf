# ===============================================================================
# Hub Module - Outputs
# ===============================================================================

output "resource_group_name" {
  description = "Name of the hub resource group"
  value       = azurerm_resource_group.hub.name
}

output "resource_group_id" {
  description = "ID of the hub resource group"
  value       = azurerm_resource_group.hub.id
}

output "vnet_id" {
  description = "ID of the hub VNet"
  value       = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  description = "Name of the hub VNet"
  value       = azurerm_virtual_network.hub.name
}

output "vnet_cidr_ipv4" {
  description = "IPv4 CIDR of the hub VNet"
  value       = var.vnet_cidr_ipv4
}

output "vnet_cidr_ipv6" {
  description = "IPv6 CIDR of the hub VNet"
  value       = var.vnet_cidr_ipv6
}

output "firewall_id" {
  description = "ID of the Azure Firewall"
  value       = azurerm_firewall.hub.id
}

output "firewall_name" {
  description = "Name of the Azure Firewall"
  value       = azurerm_firewall.hub.name
}

output "firewall_private_ip" {
  description = "Private IP address of the Azure Firewall"
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP address of the Azure Firewall"
  value       = azurerm_public_ip.firewall.ip_address
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = azurerm_nat_gateway.hub.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = azurerm_public_ip.nat.ip_address
}

output "spoke_route_table_id" {
  description = "ID of the route table for spoke subnets"
  value       = azurerm_route_table.spoke.id
}

output "spoke_route_table_name" {
  description = "Name of the route table for spoke subnets"
  value       = azurerm_route_table.spoke.name
}

output "expressroute_gateway_id" {
  description = "ID of the ExpressRoute virtual network gateway (if enabled)"
  value       = try(azurerm_virtual_network_gateway.expressroute[0].id, null)
}

output "expressroute_gateway_name" {
  description = "Name of the ExpressRoute virtual network gateway (if enabled)"
  value       = try(azurerm_virtual_network_gateway.expressroute[0].name, null)
}

output "gateway_subnet_id" {
  description = "ID of GatewaySubnet (if enabled)"
  value       = try(azurerm_subnet.gateway[0].id, null)
}
