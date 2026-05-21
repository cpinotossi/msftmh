# ===============================================================================
# Outputs - Test Runner
# ===============================================================================

output "vm_id" {
  description = "ID of the test runner VM (empty when user_count=0)"
  value       = local.deploy > 0 ? azurerm_linux_virtual_machine.test[0].id : ""
}

output "vm_name" {
  description = "Name of the test runner VM"
  value       = local.deploy > 0 ? azurerm_linux_virtual_machine.test[0].name : ""
}

output "resource_group_name" {
  description = "Resource group of the test runner"
  value       = local.deploy > 0 ? azurerm_resource_group.test[0].name : ""
}

output "managed_identity_principal_id" {
  description = "Principal ID of the test runner managed identity"
  value       = local.deploy > 0 ? azurerm_linux_virtual_machine.test[0].identity[0].principal_id : ""
}

output "deployed" {
  description = "Whether the test runner is deployed"
  value       = local.deploy > 0
}
