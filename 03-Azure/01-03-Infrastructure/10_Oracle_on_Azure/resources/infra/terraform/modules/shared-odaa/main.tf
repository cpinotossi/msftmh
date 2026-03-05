# ===============================================================================
# Shared ODAA Module - Shared Oracle Database@Azure Infrastructure
# ===============================================================================
# This module creates the shared ODAA networking infrastructure:
# - Resource Group (rg-odaa-shared)
# - Virtual Network with Oracle delegated Subnet (shared by all users)
# - Oracle Resource Anchor (global, links to OCI compartment)
# ===============================================================================

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "shared_odaa" {
  name     = "rg-odaa-shared"
  location = var.location
  tags     = var.tags
}

# ===============================================================================
# Virtual Network (shared by all users)
# ===============================================================================

resource "azurerm_virtual_network" "shared_odaa" {
  name                = "vnet-odaa-shared"
  location            = azurerm_resource_group.shared_odaa.location
  resource_group_name = azurerm_resource_group.shared_odaa.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# ===============================================================================
# Subnet with Oracle Delegation (shared by all users)
# ===============================================================================

resource "azurerm_subnet" "shared_odaa" {
  name                 = "snet-odaa-delegated"
  resource_group_name  = azurerm_resource_group.shared_odaa.name
  virtual_network_name = azurerm_virtual_network.shared_odaa.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 0)] # /24 from /16

  default_outbound_access_enabled = true

  delegation {
    name = "oracle-delegation"
    service_delegation {
      name = "Oracle.Database/networkAttachments"
      actions = [
        "Microsoft.Network/networkinterfaces/*",
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# ===============================================================================
# Virtual Network for BaseDB (shared by all users)
# ===============================================================================

resource "azurerm_virtual_network" "basedb" {
  name                = "vnet-odaa-basedb"
  location            = azurerm_resource_group.shared_odaa.location
  resource_group_name = azurerm_resource_group.shared_odaa.name
  address_space       = [var.basedb_vnet_cidr]
  tags                = var.tags
}

# ===============================================================================
# Subnet with Oracle Delegation for BaseDB
# ===============================================================================

resource "azurerm_subnet" "basedb" {
  name                 = "snet-odaa-basedb-delegated"
  resource_group_name  = azurerm_resource_group.shared_odaa.name
  virtual_network_name = azurerm_virtual_network.basedb.name
  address_prefixes     = [cidrsubnet(var.basedb_vnet_cidr, 8, 0)] # /24 from /16

  default_outbound_access_enabled = true

  delegation {
    name = "oracle-delegation"
    service_delegation {
      name = "Oracle.Database/networkAttachments"
      actions = [
        "Microsoft.Network/networkinterfaces/*",
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# ===============================================================================
# NOTE: DNS zones are created per user in the user-vm module.
# Each user gets their own Private DNS Zone linked to their VM VNet.
# ===============================================================================

# ===============================================================================
# Oracle Resource Anchor (global — links to OCI compartment)
# ===============================================================================
# The linkedCompartmentId is read-only and set by the OCI side configuration.
# The resource anchor is created with just a location (global).
# ===============================================================================

resource "azapi_resource" "resource_anchor" {
  type      = "Oracle.Database/resourceAnchors@2025-09-01"
  name      = "anchor-odaa-shared"
  parent_id = azurerm_resource_group.shared_odaa.id
  location  = "global"

  body = {}

  lifecycle {
    ignore_changes = [body]
  }
}
