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
  value       = azurerm_resource_group.test.name
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
  description = "Private DNS zone name managed by test runner"
  value       = azurerm_private_dns_zone.test.name
}

output "dns_zone_rg" {
  description = "Resource group containing the test DNS zone"
  value       = azurerm_resource_group.test.name
}
