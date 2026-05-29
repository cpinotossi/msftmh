# ===============================================================================
# Shared Infrastructure - Compute Gallery, ODAA VNets, Role Definition
# ===============================================================================
# This project manages long-lived shared resources:
# - Compute Gallery + Image Definition (sub-mhcore)
# - Shared ODAA VNets + Subnets + Resource Anchor (sub-mhodaa)
# - Custom Role Definition + Group RBAC (sub-mhodaa)
#
# Lifecycle: Deploy once, rarely changes. Users/ project reads outputs.
# ===============================================================================

# ===============================================================================
# SHARED RESOURCES — Compute Gallery (sub-mhcore)
# ===============================================================================

resource "azurerm_resource_group" "shared" {
  provider = azurerm.mhcore
  name     = "rg-shared-${var.prefix}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_shared_image_gallery" "gallery" {
  provider            = azurerm.mhcore
  name                = var.gallery_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  description         = "Shared image gallery for Oracle Workshop VMs"
  tags                = var.tags
}

resource "azurerm_shared_image" "oracle_workshop" {
  provider                  = azurerm.mhcore
  name                      = var.image_name
  gallery_name              = azurerm_shared_image_gallery.gallery.name
  resource_group_name       = azurerm_resource_group.shared.name
  location                  = azurerm_resource_group.shared.location
  os_type                   = "Linux"
  hyper_v_generation        = "V2"
  architecture              = "x64"
  trusted_launch_supported  = true

  identifier {
    publisher = "OracleWorkshop"
    offer     = "oracle-tools"
    sku       = "ubuntu-2404"
  }

  tags = var.tags
}

# ===============================================================================
# SHARED ODAA — VNet, Subnet, Resource Anchor (sub-mhodaa)
# ===============================================================================

resource "azurerm_resource_group" "shared_odaa" {
  provider = azurerm.mhodaa
  name     = "rg-odaa-shared"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "shared_odaa" {
  provider            = azurerm.mhodaa
  name                = "vnet-odaa-shared"
  location            = azurerm_resource_group.shared_odaa.location
  resource_group_name = azurerm_resource_group.shared_odaa.name
  address_space       = [var.odaa_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "shared_odaa" {
  provider             = azurerm.mhodaa
  name                 = "snet-odaa-delegated"
  resource_group_name  = azurerm_resource_group.shared_odaa.name
  virtual_network_name = azurerm_virtual_network.shared_odaa.name
  address_prefixes     = [cidrsubnet(var.odaa_vnet_cidr, 8, 0)]

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

# ===============================================================================
# CUSTOM ROLE: Oracle Database Creator (least-privilege for ADB + BaseDB)
# ===============================================================================

import {
  to = azurerm_role_definition.odaa_db_creator
  id = "/subscriptions/${var.mhodaa_subscription_id}/providers/Microsoft.Authorization/roleDefinitions/c02191a8-7480-6430-d9fc-2d006164a261|/subscriptions/${var.mhodaa_subscription_id}"
}

resource "azurerm_role_definition" "odaa_db_creator" {
  provider = azurerm.mhodaa

  name        = "Oracle Database Creator"
  scope       = "/subscriptions/${var.mhodaa_subscription_id}"
  description = "Allows creating and managing Oracle ADB and BaseDB resources, and using existing VNets/Subnets. Workshop least-privilege role."

  permissions {
    actions = [
      # Oracle Database@Azure - full access
      "Oracle.Database/*",

      # Network - read + join (use existing shared VNet/Subnet)
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/networkInterfaces/write",
      "Microsoft.Network/networkInterfaces/delete",
      "Microsoft.Network/networkInterfaces/join/action",

      # Portal creates ARM deployments behind the scenes
      "Microsoft.Resources/deployments/*",

      # Read resource group (already exists, created by Terraform)
      "Microsoft.Resources/subscriptions/resourceGroups/read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    "/subscriptions/${var.mhodaa_subscription_id}"
  ]
}

# ===============================================================================
# RBAC: User group gets Oracle Database Creator on ODAA subscription
# ===============================================================================
# Scope must be subscription-level because the Portal Create wizard calls
# subscription-level APIs (e.g. listCloudAccountDetails, oracleSubscriptions).
# A resource-group-scoped assignment causes 403 on those calls.
# ===============================================================================

resource "azurerm_role_assignment" "shared_odaa_group" {
  provider           = azurerm.mhodaa
  scope              = "/subscriptions/${var.mhodaa_subscription_id}"
  role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
  principal_id       = var.odaa_user_group_id
  description        = "Allows workshop user group to create Oracle DBs and use shared VNet"
}

# ===============================================================================
# State migration: inlined shared + shared-odaa modules
# ===============================================================================

moved {
  from = module.shared.azurerm_resource_group.shared
  to   = azurerm_resource_group.shared
}

moved {
  from = module.shared.azurerm_shared_image_gallery.gallery
  to   = azurerm_shared_image_gallery.gallery
}

moved {
  from = module.shared.azurerm_shared_image.oracle_workshop
  to   = azurerm_shared_image.oracle_workshop
}

moved {
  from = module.shared_odaa.azurerm_resource_group.shared_odaa
  to   = azurerm_resource_group.shared_odaa
}

moved {
  from = module.shared_odaa.azurerm_virtual_network.shared_odaa
  to   = azurerm_virtual_network.shared_odaa
}

moved {
  from = module.shared_odaa.azurerm_subnet.shared_odaa
  to   = azurerm_subnet.shared_odaa
}

moved {
  from = module.shared_odaa.azurerm_virtual_network.basedb
  to   = azurerm_virtual_network.basedb
}

moved {
  from = module.shared_odaa.azurerm_subnet.basedb
  to   = azurerm_subnet.basedb
}

moved {
  from = module.shared_odaa.azapi_resource.resource_anchor
  to   = azapi_resource.resource_anchor
}
