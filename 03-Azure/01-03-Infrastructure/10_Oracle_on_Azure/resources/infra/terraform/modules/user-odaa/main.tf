# ===============================================================================
# User ODAA Module - Oracle Database@Azure Infrastructure per User
# ===============================================================================
# This module creates ODAA infrastructure for a single workshop user:
# - Resource Group
# - Virtual Network with Oracle delegated Subnet
# ===============================================================================

locals {
  user_suffix = format("%02d", var.user_index)
  name_prefix = "user${local.user_suffix}"
}

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "odaa" {
  name     = "rg-odaa-${local.name_prefix}"
  location = var.location
  tags     = merge(var.tags, { UserIndex = var.user_index })
}

# ===============================================================================
# Virtual Network
# ===============================================================================

resource "azurerm_virtual_network" "odaa" {
  name                = "vnet-odaa-${local.name_prefix}"
  location            = azurerm_resource_group.odaa.location
  resource_group_name = azurerm_resource_group.odaa.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# ===============================================================================
# Subnet with Oracle Delegation
# ===============================================================================

resource "azurerm_subnet" "odaa" {
  name                 = "snet-odaa-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.odaa.name
  virtual_network_name = azurerm_virtual_network.odaa.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 0)] # /24 subnet

  delegation {
    name = "oracle-delegation"
    service_delegation {
      name = "Oracle.Database/networkAttachments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }

  # Prevent deletion while Oracle databases might be using this subnet
  lifecycle {
    prevent_destroy = false
  }
}
