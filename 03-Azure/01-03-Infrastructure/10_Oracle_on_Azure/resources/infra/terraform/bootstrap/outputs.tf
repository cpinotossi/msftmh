output "resource_group_name" {
  description = "Bootstrap resource group"
  value       = azurerm_resource_group.bootstrap.name
}

output "container_app_environment_id" {
  description = "Container Apps environment ID"
  value       = azurerm_container_app_environment.bootstrap.id
}

output "container_app_job_name" {
  description = "Container Apps job name (if created)"
  value       = var.create_container_apps_job ? azurerm_container_app_job.orchestrator[0].name : null
}

output "job_managed_identity_client_id" {
  description = "User assigned managed identity client ID for ACA job"
  value       = azurerm_user_assigned_identity.job.client_id
}

output "federated_identity_subject" {
  description = "Configured GitHub OIDC subject"
  value       = local.github_subject
}

output "key_vault_name" {
  description = "Key Vault name for OCI secrets (if created)"
  value       = var.create_key_vault ? azurerm_key_vault.oci[0].name : null
}
