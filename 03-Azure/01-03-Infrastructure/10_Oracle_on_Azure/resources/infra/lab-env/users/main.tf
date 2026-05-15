# ===============================================================================
# Users Infrastructure - Per-User VMs, ODAA RGs, Peerings
# ===============================================================================
# This project manages per-user resources (scales with var.user_count):
# - SSH key pair (shared across all VMs, admin emergency access)
# - Nx User VMs with Bastion + unique /24 VNets (sub-mh0)
# - Nx User ODAA RGs with RBAC (sub-mhodaa)
# - Nx VNet peerings (user VM VNet <-> shared ODAA VNet)
# - Nx VNet peerings (user VM VNet <-> shared BaseDB VNet)
# - Nx DNS zone links (per-user DNS zone -> user VM VNet)
#
# Reads shared infrastructure outputs (Gallery, VNets, Role Def) from
# the shared/ project via terraform_remote_state.
# ===============================================================================

# ===============================================================================
# Shared outputs (from shared/ project)
# ===============================================================================

locals {
  shared    = data.terraform_remote_state.shared.outputs
  user_keys = toset([for i in range(var.user_count) : format("%02d", i)])
}

# ===============================================================================
# SSH Key Pair (shared across all workshop VMs)
# ===============================================================================
# Auto-generated RSA key pair. Workshop users login via 'az ssh vm' (Entra ID).
# This key is only for admin emergency access.
# ===============================================================================

resource "tls_private_key" "workshop" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ===============================================================================
# USER VMs — One per user (sub-mh0)
# ===============================================================================

module "user_vm" {
  for_each = local.user_keys
  source   = "../modules/user-vm"

  providers = {
    azurerm = azurerm.mh0
  }

  user_index           = tonumber(each.key)
  location             = var.location
  vnet_cidr            = "10.0.${tonumber(each.key)}.0/24"
  vm_size              = var.vm_size
  vm_image_id          = var.vm_image_version != null ? "${local.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username       = var.admin_username
  admin_ssh_public_key = tls_private_key.workshop.public_key_openssh
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

resource "azurerm_resource_group" "user_odaa" {
  for_each = local.user_keys
  provider = azurerm.mhodaa
  name     = "rg-odaa-user${each.key}"
  location = var.location
  tags     = merge(var.tags, { UserIndex = tonumber(each.key) })
}

resource "azurerm_role_assignment" "user_odaa_db_creator" {
  for_each           = { for k, v in local.user_keys : k => k if lookup(var.user_object_ids, k, null) != null }
  provider           = azurerm.mhodaa
  scope              = azurerm_resource_group.user_odaa[each.key].id
  role_definition_id = local.shared.odaa_role_definition_resource_id
  principal_id       = var.user_object_ids[each.key]
  description        = "Allows Entra ID user to create Oracle ADB/BaseDB in ${azurerm_resource_group.user_odaa[each.key].name}"
}

# ===============================================================================
# State migration: user-odaa module inlined
# ===============================================================================

moved {
  from = module.user_odaa["00"].azurerm_resource_group.odaa
  to   = azurerm_resource_group.user_odaa["00"]
}

moved {
  from = module.user_odaa["00"].azurerm_role_assignment.odaa_db_creator[0]
  to   = azurerm_role_assignment.user_odaa_db_creator["00"]
}

# ===============================================================================
# VNET PEERING — User VM VNet <-> Shared ODAA VNet (ADB)
# ===============================================================================

module "peering" {
  for_each = local.user_keys
  source   = "../modules/vnet-peering"

  providers = {
    azurerm.mh0    = azurerm.mh0
    azurerm.mhodaa = azurerm.mhodaa
  }

  vm_vnet_id          = module.user_vm[each.key].vnet_id
  vm_vnet_name        = module.user_vm[each.key].vnet_name
  vm_resource_group   = module.user_vm[each.key].resource_group_name
  odaa_vnet_id        = local.shared.odaa_vnet_id
  odaa_vnet_name      = local.shared.odaa_vnet_name
  odaa_resource_group = local.shared.odaa_resource_group_name
  peering_suffix      = "user${each.key}"
  tags                = var.tags
}

# ===============================================================================
# VNET PEERING — User VM VNet <-> Shared BaseDB VNet
# ===============================================================================

module "peering_basedb" {
  for_each = local.user_keys
  source   = "../modules/vnet-peering"

  providers = {
    azurerm.mh0    = azurerm.mh0
    azurerm.mhodaa = azurerm.mhodaa
  }

  vm_vnet_id          = module.user_vm[each.key].vnet_id
  vm_vnet_name        = module.user_vm[each.key].vnet_name
  vm_resource_group   = module.user_vm[each.key].resource_group_name
  odaa_vnet_id        = local.shared.basedb_vnet_id
  odaa_vnet_name      = local.shared.basedb_vnet_name
  odaa_resource_group = local.shared.odaa_resource_group_name
  peering_suffix      = "basedb-user${each.key}"
  tags                = var.tags
}
