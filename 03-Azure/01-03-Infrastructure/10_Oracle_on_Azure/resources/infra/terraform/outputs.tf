# ===============================================================================
# Outputs - Shared ODAA VNet Architecture
# ===============================================================================

# ===============================================================================
# Shared Resources
# ===============================================================================

output "gallery_id" {
  description = "ID of the Compute Gallery"
  value       = module.shared.gallery_id
}

output "image_id" {
  description = "ID of the Image Definition"
  value       = module.shared.image_id
}

output "shared_odaa_info" {
  description = "Shared ODAA infrastructure info"
  value = {
    resource_group    = module.shared_odaa.resource_group_name
    vnet_id           = module.shared_odaa.vnet_id
    vnet_name         = module.shared_odaa.vnet_name
    subnet_id         = module.shared_odaa.subnet_id
    basedb_vnet_id     = module.shared_odaa.basedb_vnet_id
    basedb_vnet_name   = module.shared_odaa.basedb_vnet_name
    basedb_subnet_id   = module.shared_odaa.basedb_subnet_id
    resource_anchor_id = module.shared_odaa.resource_anchor_id
  }
}

# ===============================================================================
# Per-User VM Info (dynamic — driven by var.user_count)
# ===============================================================================

output "user_vm_info" {
  description = "VM information for all users"
  value = {
    for key, vm in module.user_vm : "user${key}" => {
      vm_id          = vm.vm_id
      vm_name        = vm.vm_name
      public_ip      = vm.public_ip_address
      private_ip     = vm.private_ip_address
      resource_group = vm.resource_group_name
      vnet_id        = vm.vnet_id
    }
  }
}

output "user_odaa_rgs" {
  description = "ODAA resource group names for all users"
  value = {
    for key, odaa in module.user_odaa : "user${key}" => odaa.resource_group_name
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to all user VMs"
  value = {
    for key, vm in module.user_vm : "user${key}" =>
      vm.public_ip_address != null ? "az ssh vm --ip ${vm.public_ip_address}" : "No public IP"
  }
}

# ===============================================================================
# SSH Private Key (for admin emergency access)
# ===============================================================================

output "ssh_private_key" {
  description = "SSH private key for admin emergency access"
  value       = module.shared.ssh_private_key
  sensitive   = true
}
