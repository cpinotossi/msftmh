# ===============================================================================
# Outputs - Test Runner
# ===============================================================================

output "vm_id" {
  description = "ID of the test runner VM"
  value       = azurerm_linux_virtual_machine.test.id
}

output "vm_name" {
  description = "Name of the test runner VM"
  value       = azurerm_linux_virtual_machine.test.name
}

output "resource_group_name" {
  description = "Resource group of the test runner"
  value       = data.azurerm_resource_group.test.name
}

output "managed_identity_principal_id" {
  description = "Principal ID of the test runner managed identity"
  value       = azurerm_linux_virtual_machine.test.identity[0].principal_id
}

output "deployed" {
  description = "Whether the test runner is deployed"
  value       = true
}

output "vnet_id" {
  description = "VNet ID of the test runner (for DNS zone link)"
  value       = azurerm_virtual_network.test.id
}

output "dns_zone_name" {
  description = "Centrally managed private DNS zone"
  value       = local.shared.central_dns_zone_name
}

output "dns_zone_rg" {
  description = "Resource group containing the test DNS zone"
  value       = local.shared.central_dns_zone_resource_group_name
}

output "odaa_resource_group_name" {
  value = azurerm_resource_group.odaa_test.name
}
