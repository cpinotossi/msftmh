# ===============================================================================
# Outputs - Test Configuration (User 00 + User 01)
# ===============================================================================

output "gallery_id" {
  description = "ID of the Compute Gallery"
  value       = module.shared.gallery_id
}

output "image_id" {
  description = "ID of the Image Definition"
  value       = module.shared.image_id
}

# ===============================================================================
# User 00 - BaseDB + BYOL
# ===============================================================================

output "user_00_dns_zone" {
  description = "Private DNS Zone info for User 00 (per-user zone)"
  value = {
    name           = module.user_vm_00.dns_zone_name
    resource_group = module.user_vm_00.dns_zone_resource_group
    id             = module.user_vm_00.dns_zone_id
  }
}

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

output "user_00_odaa_info" {
  description = "ODAA info for User 00 (BaseDB)"
  value = {
    db_type                  = module.user_odaa_00.db_type
    vnet_id                  = module.user_odaa_00.vnet_id
    vnet_name                = module.user_odaa_00.vnet_name
    resource_group           = module.user_odaa_00.resource_group_name
    subnet_id                = module.user_odaa_00.subnet_id
    exadata_infrastructure_id = module.user_odaa_00.exadata_infrastructure_id
    cloud_vm_cluster_id      = module.user_odaa_00.cloud_vm_cluster_id
  }
}

output "ssh_command_user00" {
  description = "SSH command to connect to User 00 VM"
  value       = module.user_vm_00.public_ip_address != null ? "az ssh vm --ip ${module.user_vm_00.public_ip_address}" : "No public IP"
}

# ===============================================================================
# User 01 - ADB + BYOL
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

output "user_01_odaa_info" {
  description = "ODAA info for User 01 (ADB)"
  value = {
    db_type        = module.user_odaa_01.db_type
    vnet_id        = module.user_odaa_01.vnet_id
    vnet_name      = module.user_odaa_01.vnet_name
    resource_group = module.user_odaa_01.resource_group_name
    subnet_id      = module.user_odaa_01.subnet_id
    adb_id         = module.user_odaa_01.adb_id
    adb_name       = module.user_odaa_01.adb_name
  }
}

output "ssh_command_user01" {
  description = "SSH command to connect to User 01 VM"
  value       = module.user_vm_01.public_ip_address != null ? "az ssh vm --ip ${module.user_vm_01.public_ip_address}" : "No public IP"
}
