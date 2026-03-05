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
# User 00 — Peter Parker
# ===============================================================================

output "user_00_vm_info" {
  description = "VM information for User 00"
  value = {
    vm_id          = module.user_vm_00.vm_id
    vm_name        = module.user_vm_00.vm_name
    public_ip      = module.user_vm_00.public_ip_address
    private_ip     = module.user_vm_00.private_ip_address
    resource_group = module.user_vm_00.resource_group_name
    vnet_id        = module.user_vm_00.vnet_id
  }
}

output "user_00_odaa_rg" {
  description = "ODAA RG for User 00"
  value       = module.user_odaa_00.resource_group_name
}

output "ssh_command_user00" {
  description = "SSH command to connect to User 00 VM"
  value       = module.user_vm_00.public_ip_address != null ? "az ssh vm --ip ${module.user_vm_00.public_ip_address}" : "No public IP"
}

# ===============================================================================
# User 01 — Bruce Wayne
# ===============================================================================

output "user_01_vm_info" {
  description = "VM information for User 01"
  value = {
    vm_id          = module.user_vm_01.vm_id
    vm_name        = module.user_vm_01.vm_name
    public_ip      = module.user_vm_01.public_ip_address
    private_ip     = module.user_vm_01.private_ip_address
    resource_group = module.user_vm_01.resource_group_name
    vnet_id        = module.user_vm_01.vnet_id
  }
}

output "user_01_odaa_rg" {
  description = "ODAA RG for User 01"
  value       = module.user_odaa_01.resource_group_name
}

output "ssh_command_user01" {
  description = "SSH command to connect to User 01 VM"
  value       = module.user_vm_01.public_ip_address != null ? "az ssh vm --ip ${module.user_vm_01.public_ip_address}" : "No public IP"
}

# ===============================================================================
# User 02 — Diana Prince
# ===============================================================================

output "user_02_vm_info" {
  description = "VM information for User 02"
  value = {
    vm_id          = module.user_vm_02.vm_id
    vm_name        = module.user_vm_02.vm_name
    public_ip      = module.user_vm_02.public_ip_address
    private_ip     = module.user_vm_02.private_ip_address
    resource_group = module.user_vm_02.resource_group_name
    vnet_id        = module.user_vm_02.vnet_id
  }
}

output "user_02_odaa_rg" {
  description = "ODAA RG for User 02"
  value       = module.user_odaa_02.resource_group_name
}

output "ssh_command_user02" {
  description = "SSH command to connect to User 02 VM"
  value       = module.user_vm_02.public_ip_address != null ? "az ssh vm --ip ${module.user_vm_02.public_ip_address}" : "No public IP"
}

# ===============================================================================
# SSH Private Key (for admin emergency access)
# ===============================================================================

output "ssh_private_key" {
  description = "SSH private key for admin emergency access"
  value       = module.shared.ssh_private_key
  sensitive   = true
}

