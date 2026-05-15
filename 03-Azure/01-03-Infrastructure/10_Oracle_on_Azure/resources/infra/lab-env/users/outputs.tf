# ===============================================================================
# Outputs - Users Infrastructure
# ===============================================================================

# ===============================================================================
# Per-User VM Info
# ===============================================================================

output "user_vm_info" {
  description = "VM information for all users"
  value = {
    for key, vm in module.user_vm : "user${key}" => {
      vm_id          = vm.vm_id
      vm_name        = vm.vm_name
      public_ip      = vm.public_ip_address
      private_ip     = vm.private_ip_address
      bastion_name   = vm.bastion_host_name
      bastion_ip     = vm.bastion_public_ip_address
      resource_group = vm.resource_group_name
      vnet_id        = vm.vnet_id
    }
  }
}

output "user_odaa_rgs" {
  description = "ODAA resource group names for all users"
  value = {
    for key, rg in azurerm_resource_group.user_odaa : "user${key}" => rg.name
  }
}

output "ssh_commands" {
  description = "Bastion SSH commands to connect to all user VMs"
  value = {
    for key, vm in module.user_vm : "user${key}" =>
    vm.bastion_host_name != null ? "az network bastion ssh --name ${vm.bastion_host_name} --resource-group ${vm.resource_group_name} --target-resource-id ${vm.vm_id} --auth-type AAD" : "No Bastion"
  }
}

# ===============================================================================
# SSH Private Key (for admin emergency access)
# ===============================================================================

output "ssh_private_key" {
  description = "SSH private key for admin emergency access"
  value       = tls_private_key.workshop.private_key_pem
  sensitive   = true
}
