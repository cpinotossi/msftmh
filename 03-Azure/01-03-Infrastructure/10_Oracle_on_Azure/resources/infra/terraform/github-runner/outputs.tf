# ===============================================================================
# Outputs - GitHub Actions Runner on Container Apps (AVM Version)
# ===============================================================================

output "runner_resource_group" {
  description = "Resource group containing the runner infrastructure"
  value       = azurerm_resource_group.runner.name
}

output "avm_module_outputs" {
  description = "AVM module outputs for CI/CD runners"
  value       = module.github_runner
  sensitive   = true
}

output "managed_identity" {
  description = "Managed Identity details for the runner"
  value = {
    name         = azurerm_user_assigned_identity.runner.name
    client_id    = azurerm_user_assigned_identity.runner.client_id
    principal_id = azurerm_user_assigned_identity.runner.principal_id
  }
}

output "terraform_state_storage" {
  description = "Storage account for Terraform remote state"
  value = {
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
    resource_group_name  = azurerm_resource_group.runner.name
  }
}

output "workflow_env_vars" {
  description = "Environment variables to use in GitHub Actions workflows"
  value = {
    ARM_USE_MSI         = "true"
    ARM_TENANT_ID       = var.tenant_id
    ARM_CLIENT_ID       = azurerm_user_assigned_identity.runner.client_id
    ARM_SUBSCRIPTION_ID = var.sub_mhcore_id
    TF_STATE_STORAGE    = azurerm_storage_account.tfstate.name
    TF_STATE_CONTAINER  = azurerm_storage_container.tfstate.name
    TF_STATE_RG         = azurerm_resource_group.runner.name
  }
  sensitive = false
}
