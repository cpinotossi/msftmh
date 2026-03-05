# ===============================================================================
# Oracle on Azure Workshop - Shared ODAA VNet Architecture
# ===============================================================================
# This configuration deploys workshop infrastructure for 25 users:
# - 1x Shared Gallery resources (sub-mhcore: Compute Gallery, SSH key)
# - 1x Shared ODAA resources (sub-mhodaa: VNet, Subnet, DNS, Anchors)
# - 25x User VMs with unique /24 VNets (sub-mh0)
# - 25x User ODAA RGs with RBAC (sub-mhodaa)
# - 25x VNet peerings (per-user VM VNet <-> shared ODAA VNet)
# - 25x DNS zone links (shared DNS zone -> per-user VM VNet)
#
# 3 Subscriptions:
# - sub-mhcore (gallery_subscription_id): Compute Gallery only
# - sub-mh0    (vm_subscription_id):      Workshop VMs, VNets
# - sub-mhodaa (odaa_subscription_id):    Shared ODAA VNet, Anchors, User RGs
#
# Design Principles:
# - All users share ONE ODAA VNet + ONE delegated subnet
# - Each user gets a unique /24 VM VNet (10.0.X.0/24) peered to shared ODAA
# - Each user gets their own ODAA RG to create databases via Portal
# - No for_each or count loops - explicit module definitions
# ===============================================================================

# ===============================================================================
# CUSTOM ROLE: Oracle Database Creator (least-privilege for ADB + BaseDB)
# ===============================================================================

resource "azurerm_role_definition" "odaa_db_creator" {
  provider = azurerm.odaa

  name        = "Oracle Database Creator"
  scope       = "/subscriptions/${var.odaa_subscription_id}"
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
    "/subscriptions/${var.odaa_subscription_id}"
  ]
}

# ===============================================================================
# SHARED RESOURCES — Compute Gallery + SSH Key (sub-mhcore)
# ===============================================================================

module "shared" {
  source = "./modules/shared"

  providers = {
    azurerm = azurerm.gallery
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
    azurerm = azurerm.odaa
    azapi   = azapi
  }

  location       = var.location
  vnet_cidr      = var.odaa_vnet_cidr
  basedb_vnet_cidr = var.basedb_vnet_cidr
  tags           = var.tags
}

# RBAC: User group gets Oracle Database Creator on shared ODAA RG
# (needed for network read/join on the shared VNet when creating DBs via Portal)
resource "azurerm_role_assignment" "shared_odaa_group" {
  provider           = azurerm.odaa
  scope              = module.shared_odaa.resource_group_id
  role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
  principal_id       = var.odaa_user_group_id
  description        = "Allows workshop user group to read/join shared ODAA VNet for DB creation"
}

# ===============================================================================
# USER 00 — Peter Parker
# ===============================================================================

module "user_vm_00" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index           = 0
  location             = var.location
  vnet_cidr            = "10.0.0.0/24"
  vm_size              = var.vm_size
  vm_image_id          = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username       = var.admin_username
  admin_ssh_public_key = module.shared.ssh_public_key
  os_disk_type         = var.vm_os_disk_type
  os_disk_size_gb      = var.vm_os_disk_size_gb
  create_public_ip     = var.create_public_ip
  create_dns_link      = true
  dns_zone_name        = var.odaa_dns_zone_name

  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "00", null)
  entra_id_admin_login    = var.entra_id_admin_login

  tags = var.tags
}

module "user_odaa_00" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 0
  location   = var.location
  tags       = var.tags

  # RBAC: Entra ID user gets Oracle Database Creator on their ODAA RG
  entra_id_user_object_id = lookup(var.user_object_ids, "00", null)
  odaa_role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
}

module "peering_00" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_00.vnet_id
  vm_vnet_name        = module.user_vm_00.vnet_name
  vm_resource_group   = module.user_vm_00.resource_group_name
  odaa_vnet_id        = module.shared_odaa.vnet_id
  odaa_vnet_name      = module.shared_odaa.vnet_name
  odaa_resource_group = module.shared_odaa.resource_group_name
  peering_suffix      = "user00"
  tags                = var.tags
}

module "peering_basedb_00" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_00.vnet_id
  vm_vnet_name        = module.user_vm_00.vnet_name
  vm_resource_group   = module.user_vm_00.resource_group_name
  odaa_vnet_id        = module.shared_odaa.basedb_vnet_id
  odaa_vnet_name      = module.shared_odaa.basedb_vnet_name
  odaa_resource_group = module.shared_odaa.resource_group_name
  peering_suffix      = "basedb-user00"
  tags                = var.tags
}

# ===============================================================================
# USER 01 — Bruce Wayne
# ===============================================================================

module "user_vm_01" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index           = 1
  location             = var.location
  vnet_cidr            = "10.0.1.0/24"
  vm_size              = var.vm_size
  vm_image_id          = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username       = var.admin_username
  admin_ssh_public_key = module.shared.ssh_public_key
  os_disk_type         = var.vm_os_disk_type
  os_disk_size_gb      = var.vm_os_disk_size_gb
  create_public_ip     = var.create_public_ip
  create_dns_link      = true
  dns_zone_name        = var.odaa_dns_zone_name

  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "01", null)
  entra_id_admin_login    = var.entra_id_admin_login

  tags = var.tags
}

module "user_odaa_01" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 1
  location   = var.location
  tags       = var.tags

  entra_id_user_object_id = lookup(var.user_object_ids, "01", null)
  odaa_role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
}

module "peering_01" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_01.vnet_id
  vm_vnet_name        = module.user_vm_01.vnet_name
  vm_resource_group   = module.user_vm_01.resource_group_name
  odaa_vnet_id        = module.shared_odaa.vnet_id
  odaa_vnet_name      = module.shared_odaa.vnet_name
  odaa_resource_group = module.shared_odaa.resource_group_name
  peering_suffix      = "user01"
  tags                = var.tags
}

module "peering_basedb_01" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_01.vnet_id
  vm_vnet_name        = module.user_vm_01.vnet_name
  vm_resource_group   = module.user_vm_01.resource_group_name
  odaa_vnet_id        = module.shared_odaa.basedb_vnet_id
  odaa_vnet_name      = module.shared_odaa.basedb_vnet_name
  odaa_resource_group = module.shared_odaa.resource_group_name
  peering_suffix      = "basedb-user01"
  tags                = var.tags
}

# ===============================================================================
# USER 02 — Diana Prince
# ===============================================================================

module "user_vm_02" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index           = 2
  location             = var.location
  vnet_cidr            = "10.0.2.0/24"
  vm_size              = var.vm_size
  vm_image_id          = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username       = var.admin_username
  admin_ssh_public_key = module.shared.ssh_public_key
  os_disk_type         = var.vm_os_disk_type
  os_disk_size_gb      = var.vm_os_disk_size_gb
  create_public_ip     = var.create_public_ip
  create_dns_link      = true
  dns_zone_name        = var.odaa_dns_zone_name

  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "02", null)
  entra_id_admin_login    = var.entra_id_admin_login

  tags = var.tags
}

module "user_odaa_02" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 2
  location   = var.location
  tags       = var.tags

  entra_id_user_object_id = lookup(var.user_object_ids, "02", null)
  odaa_role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id
}

module "peering_02" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_02.vnet_id
  vm_vnet_name        = module.user_vm_02.vnet_name
  vm_resource_group   = module.user_vm_02.resource_group_name
  odaa_vnet_id        = module.shared_odaa.vnet_id
  odaa_vnet_name      = module.shared_odaa.vnet_name
  odaa_resource_group = module.shared_odaa.resource_group_name
  peering_suffix      = "user02"
  tags                = var.tags
}

module "peering_basedb_02" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_02.vnet_id
  vm_vnet_name        = module.user_vm_02.vnet_name
  vm_resource_group   = module.user_vm_02.resource_group_name
  odaa_vnet_id        = module.shared_odaa.basedb_vnet_id
  odaa_vnet_name      = module.shared_odaa.basedb_vnet_name
  odaa_resource_group = module.shared_odaa.resource_group_name
  peering_suffix      = "basedb-user02"
  tags                = var.tags
}