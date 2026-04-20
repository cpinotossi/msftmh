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
# SSH key is NOT created here — it's managed in the users/ project.
# ===============================================================================

module "shared" {
  source = "../modules/shared"

  providers = {
    azurerm = azurerm.mhcore
  }

  location       = var.location
  gallery_name   = var.gallery_name
  image_name     = var.image_name
  create_ssh_key = false
  tags           = var.tags
}

# ===============================================================================
# SHARED ODAA — VNet, Subnet, Resource Anchor (sub-mhodaa)
# ===============================================================================

module "shared_odaa" {
  source = "../modules/shared-odaa"

  providers = {
    azurerm = azurerm.mhodaa
    azapi   = azapi
  }

  location         = var.location
  vnet_cidr        = var.odaa_vnet_cidr
  basedb_vnet_cidr = var.basedb_vnet_cidr
  tags             = var.tags
}

# ===============================================================================
# CUSTOM ROLE: Oracle Database Creator (least-privilege for ADB + BaseDB)
# ===============================================================================

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
# RBAC: User group gets Oracle Database Creator on shared ODAA RG
# ===============================================================================
# Needed for network read/join on the shared VNet when creating DBs via Portal.
# ===============================================================================

resource "azurerm_role_assignment" "shared_odaa_group" {
  provider           = azurerm.mhodaa
  scope              = module.shared_odaa.resource_group_id
  role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
  principal_id       = var.odaa_user_group_id
  description        = "Allows workshop user group to read/join shared ODAA VNet for DB creation"
}
