# ===============================================================================
# Outputs - Oracle on Azure Workshop
# ===============================================================================

# ===============================================================================
# Shared Resources
# ===============================================================================

output "shared_resource_group" {
  description = "Name of the shared resource group"
  value       = module.shared.resource_group_name
}

output "gallery_id" {
  description = "ID of the Azure Compute Gallery"
  value       = module.shared.gallery_id
}

output "image_id" {
  description = "ID of the VM image definition"
  value       = module.shared.image_id
}

output "dns_zone_id" {
  description = "ID of the Private DNS Zone for ODAA"
  value       = module.shared.dns_zone_id
}

# ===============================================================================
# User VMs - Public IPs (for SSH access)
# ===============================================================================

output "user_vm_public_ips" {
  description = "Public IP addresses of user VMs"
  value = {
    user00 = module.user_vm_00.public_ip_address
    user01 = module.user_vm_01.public_ip_address
    user02 = module.user_vm_02.public_ip_address
    user03 = module.user_vm_03.public_ip_address
    user04 = module.user_vm_04.public_ip_address
    user05 = module.user_vm_05.public_ip_address
    user06 = module.user_vm_06.public_ip_address
    user07 = module.user_vm_07.public_ip_address
    user08 = module.user_vm_08.public_ip_address
    user09 = module.user_vm_09.public_ip_address
    user10 = module.user_vm_10.public_ip_address
    user11 = module.user_vm_11.public_ip_address
    user12 = module.user_vm_12.public_ip_address
    user13 = module.user_vm_13.public_ip_address
    user14 = module.user_vm_14.public_ip_address
    user15 = module.user_vm_15.public_ip_address
    user16 = module.user_vm_16.public_ip_address
    user17 = module.user_vm_17.public_ip_address
    user18 = module.user_vm_18.public_ip_address
    user19 = module.user_vm_19.public_ip_address
    user20 = module.user_vm_20.public_ip_address
    user21 = module.user_vm_21.public_ip_address
    user22 = module.user_vm_22.public_ip_address
    user23 = module.user_vm_23.public_ip_address
    user24 = module.user_vm_24.public_ip_address
  }
}

# ===============================================================================
# User VMs - Private IPs
# ===============================================================================

output "user_vm_private_ips" {
  description = "Private IP addresses of user VMs"
  value = {
    user00 = module.user_vm_00.private_ip_address
    user01 = module.user_vm_01.private_ip_address
    user02 = module.user_vm_02.private_ip_address
    user03 = module.user_vm_03.private_ip_address
    user04 = module.user_vm_04.private_ip_address
    user05 = module.user_vm_05.private_ip_address
    user06 = module.user_vm_06.private_ip_address
    user07 = module.user_vm_07.private_ip_address
    user08 = module.user_vm_08.private_ip_address
    user09 = module.user_vm_09.private_ip_address
    user10 = module.user_vm_10.private_ip_address
    user11 = module.user_vm_11.private_ip_address
    user12 = module.user_vm_12.private_ip_address
    user13 = module.user_vm_13.private_ip_address
    user14 = module.user_vm_14.private_ip_address
    user15 = module.user_vm_15.private_ip_address
    user16 = module.user_vm_16.private_ip_address
    user17 = module.user_vm_17.private_ip_address
    user18 = module.user_vm_18.private_ip_address
    user19 = module.user_vm_19.private_ip_address
    user20 = module.user_vm_20.private_ip_address
    user21 = module.user_vm_21.private_ip_address
    user22 = module.user_vm_22.private_ip_address
    user23 = module.user_vm_23.private_ip_address
    user24 = module.user_vm_24.private_ip_address
  }
}

# ===============================================================================
# ODAA Resources
# ===============================================================================

output "odaa_vnet_ids" {
  description = "IDs of ODAA VNets for each user"
  value = {
    user00 = module.user_odaa_00.vnet_id
    user01 = module.user_odaa_01.vnet_id
    user02 = module.user_odaa_02.vnet_id
    user03 = module.user_odaa_03.vnet_id
    user04 = module.user_odaa_04.vnet_id
    user05 = module.user_odaa_05.vnet_id
    user06 = module.user_odaa_06.vnet_id
    user07 = module.user_odaa_07.vnet_id
    user08 = module.user_odaa_08.vnet_id
    user09 = module.user_odaa_09.vnet_id
    user10 = module.user_odaa_10.vnet_id
    user11 = module.user_odaa_11.vnet_id
    user12 = module.user_odaa_12.vnet_id
    user13 = module.user_odaa_13.vnet_id
    user14 = module.user_odaa_14.vnet_id
    user15 = module.user_odaa_15.vnet_id
    user16 = module.user_odaa_16.vnet_id
    user17 = module.user_odaa_17.vnet_id
    user18 = module.user_odaa_18.vnet_id
    user19 = module.user_odaa_19.vnet_id
    user20 = module.user_odaa_20.vnet_id
    user21 = module.user_odaa_21.vnet_id
    user22 = module.user_odaa_22.vnet_id
    user23 = module.user_odaa_23.vnet_id
    user24 = module.user_odaa_24.vnet_id
  }
}

output "odaa_subnet_ids" {
  description = "IDs of ODAA delegated subnets for each user"
  value = {
    user00 = module.user_odaa_00.subnet_id
    user01 = module.user_odaa_01.subnet_id
    user02 = module.user_odaa_02.subnet_id
    user03 = module.user_odaa_03.subnet_id
    user04 = module.user_odaa_04.subnet_id
    user05 = module.user_odaa_05.subnet_id
    user06 = module.user_odaa_06.subnet_id
    user07 = module.user_odaa_07.subnet_id
    user08 = module.user_odaa_08.subnet_id
    user09 = module.user_odaa_09.subnet_id
    user10 = module.user_odaa_10.subnet_id
    user11 = module.user_odaa_11.subnet_id
    user12 = module.user_odaa_12.subnet_id
    user13 = module.user_odaa_13.subnet_id
    user14 = module.user_odaa_14.subnet_id
    user15 = module.user_odaa_15.subnet_id
    user16 = module.user_odaa_16.subnet_id
    user17 = module.user_odaa_17.subnet_id
    user18 = module.user_odaa_18.subnet_id
    user19 = module.user_odaa_19.subnet_id
    user20 = module.user_odaa_20.subnet_id
    user21 = module.user_odaa_21.subnet_id
    user22 = module.user_odaa_22.subnet_id
    user23 = module.user_odaa_23.subnet_id
    user24 = module.user_odaa_24.subnet_id
  }
}
