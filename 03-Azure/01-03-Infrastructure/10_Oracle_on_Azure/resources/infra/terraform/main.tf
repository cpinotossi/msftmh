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
# USER 00
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
  admin_ssh_public_key = var.admin_ssh_public_key
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

  # Database provisioning: BaseDB + BYOL
  db_type            = "none"
  byol               = var.odaa_byol
  adb_admin_password = var.odaa_admin_password

  # BaseDB: reuse VM SSH key for Cloud VM Cluster
  basedb_ssh_public_keys = [var.admin_ssh_public_key]
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
# USER 01
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
  admin_ssh_public_key = var.admin_ssh_public_key
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

  # Database provisioning: ADB + BYOL
  db_type            = "none"
  byol               = var.odaa_byol
  adb_admin_password = var.odaa_admin_password

  # BaseDB: reuse VM SSH key (unused for ADB, but required by module)
  basedb_ssh_public_keys = [var.admin_ssh_public_key]
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
