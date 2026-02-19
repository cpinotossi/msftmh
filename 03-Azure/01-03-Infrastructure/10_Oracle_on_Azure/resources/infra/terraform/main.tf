# ===============================================================================
# Oracle on Azure Workshop - Simplified Infrastructure
# ===============================================================================
# This configuration deploys workshop infrastructure for 25 users:
# - 1x Shared resources (Compute Gallery, DNS Zone)
# - 25x User VMs with VNets
# - 25x User ODAA VNets with delegated subnets
# - 25x VNet Peerings (VM <-> ODAA)
#
# Design Principles:
# - No for_each or count loops - explicit module definitions
# - Maximum readability and debuggability
# - Each user's resources are independently defined
# ===============================================================================

# ===============================================================================
# SHARED RESOURCES
# ===============================================================================

module "shared" {
  source = "./modules/shared"

  providers = {
    azurerm = azurerm.vm
  }

  location           = var.location
  gallery_name       = var.gallery_name
  image_name         = var.image_name
  odaa_dns_zone_name = var.odaa_dns_zone_name
  tags               = var.tags
}

# ===============================================================================
# USER 00
# ===============================================================================

module "user_vm_00" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 0
  location                = var.location
  vnet_cidr               = "10.0.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "00", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
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

  user_index              = 1
  location                = var.location
  vnet_cidr               = "10.1.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "01", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
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
# USER 02
# ===============================================================================

module "user_vm_02" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 2
  location                = var.location
  vnet_cidr               = "10.2.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "02", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
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

# ===============================================================================
# USER 03
# ===============================================================================

module "user_vm_03" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 3
  location                = var.location
  vnet_cidr               = "10.3.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "03", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_03" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 3
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_03" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_03.vnet_id
  vm_vnet_name        = module.user_vm_03.vnet_name
  vm_resource_group   = module.user_vm_03.resource_group_name
  odaa_vnet_id        = module.user_odaa_03.vnet_id
  odaa_vnet_name      = module.user_odaa_03.vnet_name
  odaa_resource_group = module.user_odaa_03.resource_group_name
  peering_suffix      = "user03"
  tags                = var.tags
}

# ===============================================================================
# USER 04
# ===============================================================================

module "user_vm_04" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 4
  location                = var.location
  vnet_cidr               = "10.4.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "04", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_04" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 4
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_04" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_04.vnet_id
  vm_vnet_name        = module.user_vm_04.vnet_name
  vm_resource_group   = module.user_vm_04.resource_group_name
  odaa_vnet_id        = module.user_odaa_04.vnet_id
  odaa_vnet_name      = module.user_odaa_04.vnet_name
  odaa_resource_group = module.user_odaa_04.resource_group_name
  peering_suffix      = "user04"
  tags                = var.tags
}

# ===============================================================================
# USER 05
# ===============================================================================

module "user_vm_05" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 5
  location                = var.location
  vnet_cidr               = "10.5.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "05", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_05" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 5
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_05" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_05.vnet_id
  vm_vnet_name        = module.user_vm_05.vnet_name
  vm_resource_group   = module.user_vm_05.resource_group_name
  odaa_vnet_id        = module.user_odaa_05.vnet_id
  odaa_vnet_name      = module.user_odaa_05.vnet_name
  odaa_resource_group = module.user_odaa_05.resource_group_name
  peering_suffix      = "user05"
  tags                = var.tags
}

# ===============================================================================
# USER 06
# ===============================================================================

module "user_vm_06" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 6
  location                = var.location
  vnet_cidr               = "10.6.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "06", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_06" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 6
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_06" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_06.vnet_id
  vm_vnet_name        = module.user_vm_06.vnet_name
  vm_resource_group   = module.user_vm_06.resource_group_name
  odaa_vnet_id        = module.user_odaa_06.vnet_id
  odaa_vnet_name      = module.user_odaa_06.vnet_name
  odaa_resource_group = module.user_odaa_06.resource_group_name
  peering_suffix      = "user06"
  tags                = var.tags
}

# ===============================================================================
# USER 07
# ===============================================================================

module "user_vm_07" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 7
  location                = var.location
  vnet_cidr               = "10.7.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "07", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_07" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 7
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_07" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_07.vnet_id
  vm_vnet_name        = module.user_vm_07.vnet_name
  vm_resource_group   = module.user_vm_07.resource_group_name
  odaa_vnet_id        = module.user_odaa_07.vnet_id
  odaa_vnet_name      = module.user_odaa_07.vnet_name
  odaa_resource_group = module.user_odaa_07.resource_group_name
  peering_suffix      = "user07"
  tags                = var.tags
}

# ===============================================================================
# USER 08
# ===============================================================================

module "user_vm_08" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 8
  location                = var.location
  vnet_cidr               = "10.8.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "08", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_08" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 8
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_08" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_08.vnet_id
  vm_vnet_name        = module.user_vm_08.vnet_name
  vm_resource_group   = module.user_vm_08.resource_group_name
  odaa_vnet_id        = module.user_odaa_08.vnet_id
  odaa_vnet_name      = module.user_odaa_08.vnet_name
  odaa_resource_group = module.user_odaa_08.resource_group_name
  peering_suffix      = "user08"
  tags                = var.tags
}

# ===============================================================================
# USER 09
# ===============================================================================

module "user_vm_09" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 9
  location                = var.location
  vnet_cidr               = "10.9.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "09", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_09" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 9
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_09" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_09.vnet_id
  vm_vnet_name        = module.user_vm_09.vnet_name
  vm_resource_group   = module.user_vm_09.resource_group_name
  odaa_vnet_id        = module.user_odaa_09.vnet_id
  odaa_vnet_name      = module.user_odaa_09.vnet_name
  odaa_resource_group = module.user_odaa_09.resource_group_name
  peering_suffix      = "user09"
  tags                = var.tags
}

# ===============================================================================
# USER 10
# ===============================================================================

module "user_vm_10" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 10
  location                = var.location
  vnet_cidr               = "10.10.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "10", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_10" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 10
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_10" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_10.vnet_id
  vm_vnet_name        = module.user_vm_10.vnet_name
  vm_resource_group   = module.user_vm_10.resource_group_name
  odaa_vnet_id        = module.user_odaa_10.vnet_id
  odaa_vnet_name      = module.user_odaa_10.vnet_name
  odaa_resource_group = module.user_odaa_10.resource_group_name
  peering_suffix      = "user10"
  tags                = var.tags
}

# ===============================================================================
# USER 11
# ===============================================================================

module "user_vm_11" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 11
  location                = var.location
  vnet_cidr               = "10.11.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "11", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_11" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 11
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_11" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_11.vnet_id
  vm_vnet_name        = module.user_vm_11.vnet_name
  vm_resource_group   = module.user_vm_11.resource_group_name
  odaa_vnet_id        = module.user_odaa_11.vnet_id
  odaa_vnet_name      = module.user_odaa_11.vnet_name
  odaa_resource_group = module.user_odaa_11.resource_group_name
  peering_suffix      = "user11"
  tags                = var.tags
}

# ===============================================================================
# USER 12
# ===============================================================================

module "user_vm_12" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 12
  location                = var.location
  vnet_cidr               = "10.12.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "12", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_12" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 12
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_12" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_12.vnet_id
  vm_vnet_name        = module.user_vm_12.vnet_name
  vm_resource_group   = module.user_vm_12.resource_group_name
  odaa_vnet_id        = module.user_odaa_12.vnet_id
  odaa_vnet_name      = module.user_odaa_12.vnet_name
  odaa_resource_group = module.user_odaa_12.resource_group_name
  peering_suffix      = "user12"
  tags                = var.tags
}

# ===============================================================================
# USER 13
# ===============================================================================

module "user_vm_13" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 13
  location                = var.location
  vnet_cidr               = "10.13.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "13", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_13" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 13
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_13" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_13.vnet_id
  vm_vnet_name        = module.user_vm_13.vnet_name
  vm_resource_group   = module.user_vm_13.resource_group_name
  odaa_vnet_id        = module.user_odaa_13.vnet_id
  odaa_vnet_name      = module.user_odaa_13.vnet_name
  odaa_resource_group = module.user_odaa_13.resource_group_name
  peering_suffix      = "user13"
  tags                = var.tags
}

# ===============================================================================
# USER 14
# ===============================================================================

module "user_vm_14" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 14
  location                = var.location
  vnet_cidr               = "10.14.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "14", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_14" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 14
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_14" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_14.vnet_id
  vm_vnet_name        = module.user_vm_14.vnet_name
  vm_resource_group   = module.user_vm_14.resource_group_name
  odaa_vnet_id        = module.user_odaa_14.vnet_id
  odaa_vnet_name      = module.user_odaa_14.vnet_name
  odaa_resource_group = module.user_odaa_14.resource_group_name
  peering_suffix      = "user14"
  tags                = var.tags
}

# ===============================================================================
# USER 15
# ===============================================================================

module "user_vm_15" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 15
  location                = var.location
  vnet_cidr               = "10.15.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "15", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_15" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 15
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_15" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_15.vnet_id
  vm_vnet_name        = module.user_vm_15.vnet_name
  vm_resource_group   = module.user_vm_15.resource_group_name
  odaa_vnet_id        = module.user_odaa_15.vnet_id
  odaa_vnet_name      = module.user_odaa_15.vnet_name
  odaa_resource_group = module.user_odaa_15.resource_group_name
  peering_suffix      = "user15"
  tags                = var.tags
}

# ===============================================================================
# USER 16
# ===============================================================================

module "user_vm_16" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 16
  location                = var.location
  vnet_cidr               = "10.16.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "16", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_16" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 16
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_16" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_16.vnet_id
  vm_vnet_name        = module.user_vm_16.vnet_name
  vm_resource_group   = module.user_vm_16.resource_group_name
  odaa_vnet_id        = module.user_odaa_16.vnet_id
  odaa_vnet_name      = module.user_odaa_16.vnet_name
  odaa_resource_group = module.user_odaa_16.resource_group_name
  peering_suffix      = "user16"
  tags                = var.tags
}

# ===============================================================================
# USER 17
# ===============================================================================

module "user_vm_17" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 17
  location                = var.location
  vnet_cidr               = "10.17.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "17", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_17" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 17
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_17" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_17.vnet_id
  vm_vnet_name        = module.user_vm_17.vnet_name
  vm_resource_group   = module.user_vm_17.resource_group_name
  odaa_vnet_id        = module.user_odaa_17.vnet_id
  odaa_vnet_name      = module.user_odaa_17.vnet_name
  odaa_resource_group = module.user_odaa_17.resource_group_name
  peering_suffix      = "user17"
  tags                = var.tags
}

# ===============================================================================
# USER 18
# ===============================================================================

module "user_vm_18" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 18
  location                = var.location
  vnet_cidr               = "10.18.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "18", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_18" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 18
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_18" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_18.vnet_id
  vm_vnet_name        = module.user_vm_18.vnet_name
  vm_resource_group   = module.user_vm_18.resource_group_name
  odaa_vnet_id        = module.user_odaa_18.vnet_id
  odaa_vnet_name      = module.user_odaa_18.vnet_name
  odaa_resource_group = module.user_odaa_18.resource_group_name
  peering_suffix      = "user18"
  tags                = var.tags
}

# ===============================================================================
# USER 19
# ===============================================================================

module "user_vm_19" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 19
  location                = var.location
  vnet_cidr               = "10.19.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "19", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_19" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 19
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_19" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_19.vnet_id
  vm_vnet_name        = module.user_vm_19.vnet_name
  vm_resource_group   = module.user_vm_19.resource_group_name
  odaa_vnet_id        = module.user_odaa_19.vnet_id
  odaa_vnet_name      = module.user_odaa_19.vnet_name
  odaa_resource_group = module.user_odaa_19.resource_group_name
  peering_suffix      = "user19"
  tags                = var.tags
}

# ===============================================================================
# USER 20
# ===============================================================================

module "user_vm_20" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 20
  location                = var.location
  vnet_cidr               = "10.20.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "20", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_20" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 20
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_20" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_20.vnet_id
  vm_vnet_name        = module.user_vm_20.vnet_name
  vm_resource_group   = module.user_vm_20.resource_group_name
  odaa_vnet_id        = module.user_odaa_20.vnet_id
  odaa_vnet_name      = module.user_odaa_20.vnet_name
  odaa_resource_group = module.user_odaa_20.resource_group_name
  peering_suffix      = "user20"
  tags                = var.tags
}

# ===============================================================================
# USER 21
# ===============================================================================

module "user_vm_21" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 21
  location                = var.location
  vnet_cidr               = "10.21.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "21", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_21" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 21
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_21" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_21.vnet_id
  vm_vnet_name        = module.user_vm_21.vnet_name
  vm_resource_group   = module.user_vm_21.resource_group_name
  odaa_vnet_id        = module.user_odaa_21.vnet_id
  odaa_vnet_name      = module.user_odaa_21.vnet_name
  odaa_resource_group = module.user_odaa_21.resource_group_name
  peering_suffix      = "user21"
  tags                = var.tags
}

# ===============================================================================
# USER 22
# ===============================================================================

module "user_vm_22" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 22
  location                = var.location
  vnet_cidr               = "10.22.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "22", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_22" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 22
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_22" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_22.vnet_id
  vm_vnet_name        = module.user_vm_22.vnet_name
  vm_resource_group   = module.user_vm_22.resource_group_name
  odaa_vnet_id        = module.user_odaa_22.vnet_id
  odaa_vnet_name      = module.user_odaa_22.vnet_name
  odaa_resource_group = module.user_odaa_22.resource_group_name
  peering_suffix      = "user22"
  tags                = var.tags
}

# ===============================================================================
# USER 23
# ===============================================================================

module "user_vm_23" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 23
  location                = var.location
  vnet_cidr               = "10.23.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "23", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_23" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 23
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_23" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_23.vnet_id
  vm_vnet_name        = module.user_vm_23.vnet_name
  vm_resource_group   = module.user_vm_23.resource_group_name
  odaa_vnet_id        = module.user_odaa_23.vnet_id
  odaa_vnet_name      = module.user_odaa_23.vnet_name
  odaa_resource_group = module.user_odaa_23.resource_group_name
  peering_suffix      = "user23"
  tags                = var.tags
}

# ===============================================================================
# USER 24
# ===============================================================================

module "user_vm_24" {
  source = "./modules/user-vm"

  providers = {
    azurerm = azurerm.vm
  }

  user_index              = 24
  location                = var.location
  vnet_cidr               = "10.24.0.0/16"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${module.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = var.admin_ssh_public_key
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = var.create_public_ip
  dns_zone_id             = module.shared.dns_zone_id
  dns_zone_name           = module.shared.dns_zone_name
  dns_zone_resource_group = module.shared.resource_group_name
  
  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = lookup(var.user_object_ids, "24", null)
  entra_id_admin_login    = var.entra_id_admin_login
  
  tags                    = var.tags
}

module "user_odaa_24" {
  source = "./modules/user-odaa"

  providers = {
    azurerm = azurerm.odaa
  }

  user_index = 24
  location   = var.location
  vnet_cidr  = var.odaa_vnet_cidr
  tags       = var.tags
}

module "peering_24" {
  source = "./modules/vnet-peering"

  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }

  vm_vnet_id          = module.user_vm_24.vnet_id
  vm_vnet_name        = module.user_vm_24.vnet_name
  vm_resource_group   = module.user_vm_24.resource_group_name
  odaa_vnet_id        = module.user_odaa_24.vnet_id
  odaa_vnet_name      = module.user_odaa_24.vnet_name
  odaa_resource_group = module.user_odaa_24.resource_group_name
  peering_suffix      = "user24"
  tags                = var.tags
}
