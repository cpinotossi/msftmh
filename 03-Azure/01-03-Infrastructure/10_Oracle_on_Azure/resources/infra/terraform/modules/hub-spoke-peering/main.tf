# ===============================================================================
# Hub-Spoke Peering Module - Cross-Subscription VNet Peering with UDR
# ===============================================================================
# This module creates:
# - Bidirectional VNet peering between Hub and Spoke
# - Route table in spoke subscription (traffic → Hub Firewall)
# - Route table association on spoke subnet
#
# Usage:
# - When direct peering (e.g., VM↔ODAA) exists, it wins due to more specific routes
# - Comment out direct peering module → traffic flows through Hub
# ===============================================================================

terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.hub, azurerm.spoke]
    }
  }
}

# ===============================================================================
# VNet Peering: Hub to Spoke
# ===============================================================================

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = "peer-hub-to-${var.spoke_name}"
  resource_group_name       = var.hub_resource_group
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = var.spoke_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.allow_gateway_transit
  use_remote_gateways          = false

  lifecycle {
    create_before_destroy = false
  }
}

# ===============================================================================
# VNet Peering: Spoke to Hub
# ===============================================================================

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                  = azurerm.spoke
  name                      = "peer-${var.spoke_name}-to-hub"
  resource_group_name       = var.spoke_resource_group
  virtual_network_name      = var.spoke_vnet_name
  remote_virtual_network_id = var.hub_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.use_hub_gateway

  lifecycle {
    create_before_destroy = false
  }
}

# ===============================================================================
# Route Table (in spoke subscription - required for cross-subscription)
# ===============================================================================

resource "azurerm_route_table" "spoke_to_hub" {
  provider            = azurerm.spoke
  name                = "rt-${var.spoke_name}-to-hub"
  location            = var.spoke_location
  resource_group_name = var.spoke_resource_group
  tags                = var.tags

  dynamic "route" {
    for_each = toset(var.firewall_route_prefixes)
    content {
      name                   = "to-hub-firewall-${replace(replace(route.value, ".", "-"), "/", "-")}"
      address_prefix         = route.value
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.hub_firewall_private_ip
    }
  }
}

# ===============================================================================
# Route Table Association on Spoke Subnet
# ===============================================================================

resource "azurerm_subnet_route_table_association" "spoke" {
  provider       = azurerm.spoke
  subnet_id      = var.spoke_subnet_id
  route_table_id = azurerm_route_table.spoke_to_hub.id
}
