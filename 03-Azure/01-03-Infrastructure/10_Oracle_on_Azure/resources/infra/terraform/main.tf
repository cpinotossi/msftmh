# ===============================================================================
# Oracle on Azure Workshop - Simplified Infrastructure
# ===============================================================================
# This configuration deploys workshop infrastructure for 25 users:
# - 1x Shared resources (Compute Gallery, DNS Zone)
# - 25x User VMs with VNets
# - 25x User ODAA VNets with delegated subnets
# - 25x Direct VNet Peerings (VM <-> ODAA)
#
# Design Principles:
# - No for_each or count loops - explicit module definitions
# - Maximum readability and debuggability
# - Each user's resources are independently defined
# - Direct peering: each user's VM VNet peers directly with their ODAA VNet
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

      # Network - read + join (use existing VNet/Subnet created by Terraform)
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/networkInterfaces/read",

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
# SHARED RESOURCES
# ===============================================================================

module "shared" {
  source = "./modules/shared"

  providers = {
    azurerm = azurerm.vm
  }

  location     = var.location
  gallery_name = var.gallery_name
  image_name   = var.image_name
  tags         = var.tags
}

# ===============================================================================
# USER 00 Peter Parker
# ===============================================================================

module "user_vm_00" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index           = 0
  location             = var.location
  vnet_cidr            = "10.0.0.0/16"
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
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags

  # RBAC: Entra ID user gets Oracle Database Creator on their ODAA RG
  entra_id_user_object_id = lookup(var.user_object_ids, "00", null)
  odaa_role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id

  # Database provisioning: BaseDB + BYOL
  db_type            = "none"
  byol               = var.odaa_byol
  adb_admin_password = var.odaa_admin_password

  # BaseDB: reuse shared SSH key for Cloud VM Cluster
  basedb_ssh_public_keys = [module.shared.ssh_public_key]
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
  odaa_vnet_id        = module.user_odaa_00.vnet_id
  odaa_vnet_name      = module.user_odaa_00.vnet_name
  odaa_resource_group = module.user_odaa_00.resource_group_name
  peering_suffix      = "user00"
  tags                = var.tags
}

# ===============================================================================
# USER 01 Bruce Wayne
# ===============================================================================

module "user_vm_01" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index           = 1
  location             = var.location
  vnet_cidr            = "10.0.0.0/16"
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
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags

  # RBAC: Entra ID user gets Oracle Database Creator on their ODAA RG
  entra_id_user_object_id = lookup(var.user_object_ids, "01", null)
  odaa_role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id

  # Database provisioning: ADB + BYOL
  db_type            = "none"
  byol               = var.odaa_byol
  adb_admin_password = var.odaa_admin_password

  # BaseDB: reuse shared SSH key (unused for ADB, but required by module)
  basedb_ssh_public_keys = [module.shared.ssh_public_key]
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
  odaa_vnet_id        = module.user_odaa_01.vnet_id
  odaa_vnet_name      = module.user_odaa_01.vnet_name
  odaa_resource_group = module.user_odaa_01.resource_group_name
  peering_suffix      = "user01"
  tags                = var.tags
}

# ===============================================================================
# USER 02 Diana Prince
# ===============================================================================

module "user_vm_02" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index           = 2
  location             = var.location
  vnet_cidr            = "10.0.0.0/16"
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
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags

  # RBAC: Entra ID user gets Oracle Database Creator on their ODAA RG
  entra_id_user_object_id = lookup(var.user_object_ids, "02", null)
  odaa_role_definition_id = azurerm_role_definition.odaa_db_creator.role_definition_resource_id

  # Database provisioning: BaseDB + BYOL
  db_type            = "none"
  byol               = var.odaa_byol
  adb_admin_password = var.odaa_admin_password

  # BaseDB: reuse shared SSH key for Cloud VM Cluster
  basedb_ssh_public_keys = [module.shared.ssh_public_key]
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
  odaa_vnet_id        = module.user_odaa_02.vnet_id
  odaa_vnet_name      = module.user_odaa_02.vnet_name
  odaa_resource_group = module.user_odaa_02.resource_group_name
  peering_suffix      = "user02"
  tags                = var.tags
}