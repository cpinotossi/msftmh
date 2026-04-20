# ===============================================================================
# Oracle on Azure Workshop - Shared ODAA VNet Architecture
# ===============================================================================
# This configuration deploys workshop infrastructure for N users (var.user_count):
# - 1x Shared Gallery resources (sub-mhcore: Compute Gallery, SSH key)
# - 1x Shared ODAA resources (sub-mhodaa: VNet, Subnet, Anchors)
# - Nx User VMs with unique /24 VNets (sub-mh0)
# - Nx User ODAA RGs with RBAC (sub-mhodaa)
# - Nx VNet peerings (per-user VM VNet <-> shared ODAA VNet)
# - Nx VNet peerings (per-user VM VNet <-> shared BaseDB VNet)
# - Nx DNS zone links (per-user DNS zone -> per-user VM VNet)
#
# 3 Subscriptions:
# - sub-mhcore (gallery_subscription_id): Compute Gallery only
# - sub-mh0    (vm_subscription_id):      Workshop VMs, VNets
# - sub-mhodaa (odaa_subscription_id):    Shared ODAA VNet, Anchors, User RGs
#
# Design Principles:
# - Set var.user_count to control how many users to deploy (0-25)
# - All users share ONE ODAA VNet + ONE delegated subnet
# - Each user gets a unique /24 VM VNet (10.0.X.0/24) peered to shared ODAA
# - Each user gets their own ODAA RG to create databases via Portal
# - Uses for_each loops — no repetitive per-user blocks
#
# Destroy Safety:
# - Use scripts/deploy.ps1 for safe deploy/destroy with retry logic
# - Or use: terraform apply -parallelism=5
# - Azure API eventual consistency can cause "resource in use" errors
#   during parallel deletes; reduced parallelism + retries handles this
# ===============================================================================

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
# SHARED RESOURCES — Compute Gallery + SSH Key (sub-mhcore)
# ===============================================================================

module "shared" {
  source = "./modules/shared"

  providers = {
    azurerm = azurerm.mhcore
  }

  location     = var.location
  gallery_name = var.gallery_name
  image_name   = var.image_name
  tags         = var.tags
}

# ===============================================================================
# SHARED ODAA — VNet, Subnet, DNS, Resource Anchor, Network Anchor (sub-mhodaa)
# ===============================================================================

module "shared_odaa" {
  source = "./modules/shared-odaa"

  providers = {
    azurerm = azurerm.mhodaa
    azapi   = azapi
  }

  location         = var.location
  vnet_cidr        = var.odaa_vnet_cidr
  basedb_vnet_cidr = var.basedb_vnet_cidr
  tags             = var.tags
}

# RBAC: User group gets Oracle Database Creator on shared ODAA RG
# (needed for network read/join on the shared VNet when creating DBs via Portal)
resource "azurerm_role_assignment" "shared_odaa_group" {
  provider           = azurerm.mhodaa
  scope              = module.shared_odaa.resource_group_id
  role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
  principal_id       = var.odaa_user_group_id
  description        = "Allows workshop user group to read/join shared ODAA VNet for DB creation"
}

# ===============================================================================
# USER LOCALS — Generate user keys from user_count
# ===============================================================================

locals {
  # Generate user keys like "00", "01", "02", ... based on user_count
  user_keys = toset([for i in range(var.user_count) : format("%02d", i)])
}

# ===============================================================================
# USER VMs — One per user (sub-mh0)
# ===============================================================================

module "user_vm" {
  for_each = local.user_keys
  source   = "./modules/user-vm"

  providers = {
    azurerm = azurerm.mh0
  }

  user_index           = tonumber(each.key)
  location             = var.location
  vnet_cidr            = "10.0.${tonumber(each.key)}.0/24"
  vm_size              = var.vm_size
  vm_image_id          = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username       = var.admin_username
  admin_ssh_public_key = module.shared.ssh_public_key
  os_disk_type         = var.vm_os_disk_type
  os_disk_size_gb      = var.vm_os_disk_size_gb
  create_public_ip     = var.create_public_ip
  enable_bastion       = var.enable_bastion
  bastion_sku          = var.bastion_sku
  enable_nat_gateway   = var.enable_nat_gateway
  create_dns_link      = true
  dns_zone_name        = var.odaa_dns_zone_name

  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, each.key, null)
  entra_id_admin_login    = var.entra_id_admin_login

  tags = var.tags
}

# ===============================================================================
# USER ODAA RGs — One per user (sub-mhodaa)
# ===============================================================================

module "user_odaa" {
  for_each = local.user_keys
  source   = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.mhodaa
  }

  user_index = tonumber(each.key)
  location   = var.location
  tags       = var.tags

  # RBAC: Entra ID user gets Oracle Database Creator on their ODAA RG
  entra_id_user_object_id = lookup(var.user_object_ids, each.key, null)
  odaa_role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
}

# ===============================================================================
# VNET PEERING — User VM VNet <-> Shared ODAA VNet (ADB)
# ===============================================================================

module "peering" {
  for_each = local.user_keys
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.mh0    = azurerm.mh0
    azurerm.mhodaa = azurerm.mhodaa
  }

  vm_vnet_id          = module.user_vm[each.key].vnet_id
  vm_vnet_name        = module.user_vm[each.key].vnet_name
  vm_resource_group   = module.user_vm[each.key].resource_group_name
  odaa_vnet_id        = module.shared_odaa.vnet_id
  odaa_vnet_name      = module.shared_odaa.vnet_name
  odaa_resource_group = module.shared_odaa.resource_group_name
  peering_suffix      = "user${each.key}"
  tags                = var.tags
}

# ===============================================================================
# VNET PEERING — User VM VNet <-> Shared BaseDB VNet
# ===============================================================================

module "peering_basedb" {
  for_each = local.user_keys
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.mh0    = azurerm.mh0
    azurerm.mhodaa = azurerm.mhodaa
  }

  vm_vnet_id          = module.user_vm[each.key].vnet_id
  vm_vnet_name        = module.user_vm[each.key].vnet_name
  vm_resource_group   = module.user_vm[each.key].resource_group_name
  odaa_vnet_id        = module.shared_odaa.basedb_vnet_id
  odaa_vnet_name      = module.shared_odaa.basedb_vnet_name
  odaa_resource_group = module.shared_odaa.resource_group_name
  peering_suffix      = "basedb-user${each.key}"
  tags                = var.tags
}