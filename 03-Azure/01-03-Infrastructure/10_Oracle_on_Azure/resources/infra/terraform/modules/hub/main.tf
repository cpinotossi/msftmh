# ===============================================================================
# Hub Module - Central Hub Infrastructure
# ===============================================================================
# This module creates the hub infrastructure for hub-and-spoke topology:
# - Resource Group
# - Virtual Network (Dual-Stack: IPv4 + IPv6)
# - Azure Firewall (Basic SKU) with Allow-All Policy
# - NAT Gateway for outbound connectivity
# - Route Table for spokes (0.0.0.0/0 → Firewall)
# ===============================================================================

locals {
  # Subnet calculations
  firewall_subnet_cidr      = cidrsubnet(var.vnet_cidr_ipv4, 10, 0) # /26 for AzureFirewallSubnet
  nat_gateway_subnet_cidr   = cidrsubnet(var.vnet_cidr_ipv4, 10, 1) # /26 for NAT Gateway
  firewall_mgmt_subnet_cidr = cidrsubnet(var.vnet_cidr_ipv4, 10, 2) # /26 for AzureFirewallManagementSubnet (required for Basic)
  management_subnet_cidr    = cidrsubnet(var.vnet_cidr_ipv4, 8, 1)  # /24 for management

  # ExpressRoute gateway subnet (GatewaySubnet). Keep it separate from the firewall/NAT ranges.
  # /27 is the minimum recommended size for GatewaySubnet.
  gateway_subnet_cidr = cidrsubnet(var.vnet_cidr_ipv4, 11, 6) # /27 (e.g. 10.100.0.192/27)

  # IPv6 subnets
  firewall_subnet_cidr_ipv6 = cidrsubnet(var.vnet_cidr_ipv6, 64 - var.ipv6_prefix_length, 0)
}

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "hub" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ===============================================================================
# Virtual Network (Dual-Stack)
# ===============================================================================

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = [var.vnet_cidr_ipv4, var.vnet_cidr_ipv6]
  tags                = var.tags
}

# ===============================================================================
# Azure Firewall Subnet (required name: AzureFirewallSubnet)
# ===============================================================================

resource "azurerm_subnet" "firewall" {
  name                            = "AzureFirewallSubnet"
  resource_group_name             = azurerm_resource_group.hub.name
  virtual_network_name            = azurerm_virtual_network.hub.name
  address_prefixes                = [local.firewall_subnet_cidr]
  default_outbound_access_enabled = false
}

# Azure Firewall Management Subnet (required for Basic SKU)
resource "azurerm_subnet" "firewall_mgmt" {
  count                           = var.firewall_sku == "Basic" ? 1 : 0
  name                            = "AzureFirewallManagementSubnet"
  resource_group_name             = azurerm_resource_group.hub.name
  virtual_network_name            = azurerm_virtual_network.hub.name
  address_prefixes                = [local.firewall_mgmt_subnet_cidr]
  default_outbound_access_enabled = false
}

# ===============================================================================
# ExpressRoute Gateway Subnet (required name: GatewaySubnet)
# ===============================================================================

resource "azurerm_subnet" "gateway" {
  count                           = var.enable_expressroute_gateway ? 1 : 0
  name                            = "GatewaySubnet"
  resource_group_name             = azurerm_resource_group.hub.name
  virtual_network_name            = azurerm_virtual_network.hub.name
  address_prefixes                = [local.gateway_subnet_cidr]
  default_outbound_access_enabled = false
}

# ===============================================================================
# NAT Gateway for Outbound Connectivity
# ===============================================================================

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones
  tags                = var.tags
}

resource "azurerm_nat_gateway" "hub" {
  name                    = "nat-hub"
  location                = azurerm_resource_group.hub.location
  resource_group_name     = azurerm_resource_group.hub.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = var.availability_zones
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "hub" {
  nat_gateway_id       = azurerm_nat_gateway.hub.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_virtual_network_gateway" "expressroute" {
  count               = var.enable_expressroute_gateway ? 1 : 0
  name                = "vng-er-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  type = "ExpressRoute"
  sku  = var.expressroute_gateway_sku

  ip_configuration {
    name      = "vng-er-ipconfig"
    subnet_id = azurerm_subnet.gateway[0].id
  }

  tags = var.tags
}

# ===============================================================================
# Azure Firewall
# ===============================================================================

resource "azurerm_public_ip" "firewall" {
  name                = "pip-fw-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones
  tags                = var.tags
}

resource "azurerm_public_ip" "firewall_mgmt" {
  count               = var.firewall_sku == "Basic" ? 1 : 0
  name                = "pip-fwmgmt-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones
  tags                = var.tags
}

resource "azurerm_firewall_policy" "hub" {
  name                = "fwpol-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = var.firewall_sku
  tags                = var.tags
}

# Allow-All Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "allow_all" {
  name               = "rcg-allow-all"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 100

  network_rule_collection {
    name     = "allow-all-network"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-all-traffic"
      protocols             = ["Any"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }

  application_rule_collection {
    name     = "allow-all-application"
    priority = 200
    action   = "Allow"

    rule {
      name = "allow-all-fqdn"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*"]
    }
  }
}

resource "azurerm_firewall" "hub" {
  name                = "fw-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  tags                = var.tags

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  dynamic "management_ip_configuration" {
    for_each = var.firewall_sku == "Basic" ? [1] : []
    content {
      name                 = "fw-mgmt-ipconfig"
      subnet_id            = azurerm_subnet.firewall_mgmt[0].id
      public_ip_address_id = azurerm_public_ip.firewall_mgmt[0].id
    }
  }
}

# ===============================================================================
# Route Table for Spokes (to be associated with spoke subnets)
# ===============================================================================

resource "azurerm_route_table" "spoke" {
  name                = "rt-spoke-to-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags

  # Default route to firewall
  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }

  # Route for hub VNet (direct)
  route {
    name           = "to-hub-vnet"
    address_prefix = var.vnet_cidr_ipv4
    next_hop_type  = "VnetLocal"
  }
}
