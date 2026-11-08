# ===============================================================================
# Users Infrastructure - Per-User VMs, Peerings
# ===============================================================================
# This project manages per-user resources (scales with var.user_count):
# - SSH key pair (shared across all VMs, admin emergency access)
# - Nx User VMs with Bastion + unique /24 VNets (sub-mh0)
# - Nx VNet peerings (user VM VNet <-> shared ODAA VNet)
# - Nx DNS zone links (per-user DNS zone -> user VM VNet)
#
# Reads shared infrastructure outputs (Gallery, VNets, Role Def) from
# the shared/ project via terraform_remote_state.
# ===============================================================================

# ===============================================================================
# Shared outputs (from shared/ project)
# ===============================================================================

locals {
  shared          = data.terraform_remote_state.shared.outputs
  user_keys       = toset([for i in range(1, var.user_count + 1) : format("%02d", i)])
  user_object_ids = data.terraform_remote_state.identity.outputs.user_object_ids
  tags            = var.tags
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

  user_index              = tonumber(each.key)
  firewall_private_ip     = local.shared.firewall_private_ip
  hub_bastion_subnet_cidr = local.shared.hub_bastion_subnet_cidr
  odaa_subnet_cidr        = local.shared.odaa_subnet_cidr
  location                = var.location
  vnet_cidr               = "10.0.${tonumber(each.key)}.0/24"
  vm_size                 = var.vm_size
  vm_image_id             = var.vm_image_version != null ? "${local.shared.image_id}/versions/${var.vm_image_version}" : null
  admin_username          = var.admin_username
  admin_ssh_public_key    = tls_private_key.workshop.public_key_openssh
  os_disk_type            = var.vm_os_disk_type
  os_disk_size_gb         = var.vm_os_disk_size_gb
  create_public_ip        = false
  enable_bastion          = false
  enable_nat_gateway      = false
  create_dns_link         = false

  # Entra ID Login
  enable_entra_id_login   = var.enable_entra_id_login
  entra_id_user_object_id = local.user_object_ids[each.key]
  entra_id_admin_login    = var.entra_id_admin_login

  tags = local.tags
}


# ===============================================================================
# VNET PEERING — User VM VNet <-> Shared ODAA VNet (Base Database)
# ===============================================================================

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                     = azurerm.mh0
  for_each                     = local.user_keys
  name                         = "peer-mhuser${tonumber(each.key)}-to-hub"
  resource_group_name          = module.user_vm[each.key].resource_group_name
  virtual_network_name         = module.user_vm[each.key].vnet_name
  remote_virtual_network_id    = local.shared.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                     = azurerm.mh0
  for_each                     = local.user_keys
  name                         = "peer-hub-to-mhuser${tonumber(each.key)}"
  resource_group_name          = local.shared.hub_resource_group_name
  virtual_network_name         = local.shared.hub_vnet_name
  remote_virtual_network_id    = module.user_vm[each.key].vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_resource_group" "user_odaa" {
  provider = azurerm.mhodaa
  for_each = local.user_keys
  name     = "rg-odaa-mhuser${tonumber(each.key)}"
  location = var.location
  tags     = merge(local.tags, { participant = "mhuser${tonumber(each.key)}" })

  lifecycle {
    precondition {
      condition     = var.mh0_subscription_id == split("/", local.shared.hub_vnet_id)[2] && var.mh0_subscription_id != var.mhodaa_subscription_id
      error_message = "All spokes must share the hub's workshop subscription, separate from ODAA."
    }
  }
}

resource "azurerm_role_assignment" "user_odaa" {
  provider           = azurerm.mhodaa
  for_each           = local.user_keys
  scope              = azurerm_resource_group.user_odaa[each.key].id
  role_definition_id = local.shared.odaa_role_definition_resource_id
  principal_id       = local.user_object_ids[each.key]
}

resource "azurerm_private_dns_a_record" "user_vm" {
  provider            = azurerm.mh0
  for_each            = local.user_keys
  name                = "vm-mhuser${tonumber(each.key)}"
  zone_name           = local.shared.central_dns_zone_name
  resource_group_name = local.shared.central_dns_zone_resource_group_name
  ttl                 = 300
  records             = [module.user_vm[each.key].private_ip_address]
  tags                = local.tags
}
