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

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "hub_resource_group_name" {
  value = azurerm_resource_group.hub.name
}

output "hub_resource_group_id" {
  value = azurerm_resource_group.hub.id
}

output "hub_bastion_name" {
  value = azurerm_bastion_host.hub.name
}

output "hub_bastion_subnet_cidr" {
  value = azurerm_subnet.hub["AzureBastionSubnet"].address_prefixes[0]
}

output "firewall_private_ip" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "dns_resolver_inbound_ip" {
  value = azurerm_private_dns_resolver_inbound_endpoint.hub.ip_configurations[0].private_ip_address
}

output "central_dns_zone_name" {
  value = azurerm_private_dns_zone.workshop.name
}

output "central_dns_zone_id" {
  value = azurerm_private_dns_zone.workshop.id
}

output "central_dns_zone_resource_group_name" {
  value = azurerm_resource_group.hub.name
}

output "odaa_subnet_cidr" {
  value = local.oracle_cidr
}

output "network_anchor_id" {
  value = azapi_resource.network_anchor.id
}

output "network_anchor_ids_by_zone" {
  value = { (var.network_anchor_zone) = azapi_resource.network_anchor.id }
}

output "network_anchor_zone" {
  value = var.network_anchor_zone
}

output "oracle_dns_domain" {
  value = "${azapi_resource.network_anchor.output.properties.ociVcnDnsLabel}.oraclevcn.com."
}

output "oracle_dns_listening_ip" {
  value = azapi_resource.network_anchor.output.properties.dnsListeningEndpointIpAddress
}

output "oracle_dns_forwarding_ip" {
  value = azapi_resource.network_anchor.output.properties.dnsForwardingEndpointIpAddress
}
