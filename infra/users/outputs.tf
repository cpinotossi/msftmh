# ===============================================================================
# Outputs - Users Infrastructure
# ===============================================================================

# ===============================================================================
# Per-User VM Info
# ===============================================================================

output "user_vm_info" {
  description = "VM information for all users"
  value = {
    for key, vm in module.user_vm : "mhuser${tonumber(key)}" => {
      vm_id               = vm.vm_id
      vm_name             = vm.vm_name
      public_ip           = vm.public_ip_address
      private_ip          = vm.private_ip_address
      bastion_name        = local.shared.hub_bastion_name
      bastion_rg          = local.shared.hub_resource_group_name
      resource_group      = vm.resource_group_name
      vnet_id             = vm.vnet_id
      odaa_resource_group = azurerm_resource_group.user_odaa[key].name
    }
  }
}

output "ssh_commands" {
  description = "Bastion SSH commands to connect to all user VMs"
  value = {
    for key, vm in module.user_vm : "mhuser${tonumber(key)}" =>
    "az network bastion ssh --subscription ${var.mh0_subscription_id} --name ${local.shared.hub_bastion_name} --resource-group ${local.shared.hub_resource_group_name} --target-resource-id ${vm.vm_id} --auth-type AAD"
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
