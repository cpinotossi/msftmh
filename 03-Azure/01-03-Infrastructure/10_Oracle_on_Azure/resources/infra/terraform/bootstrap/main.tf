locals {
  github_subject = var.github_environment != ""
    ? "repo:${var.github_org}/${var.github_repo}:environment:${var.github_environment}"
    : "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"

  key_vault_name_effective = var.key_vault_name != "" ? var.key_vault_name : "${var.name_prefix}-gh-kv"
}

data "azurerm_client_config" "current" {}

data "azuread_application" "existing_sp" {
  client_id = var.existing_sp_client_id
}

resource "azurerm_resource_group" "bootstrap" {
  name     = "rg-${var.name_prefix}-github-bootstrap"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "bootstrap" {
  name                = "law-${var.name_prefix}-github-bootstrap"
  location            = azurerm_resource_group.bootstrap.location
  resource_group_name = azurerm_resource_group.bootstrap.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "job" {
  name                = "uami-${var.name_prefix}-aca-job"
  location            = azurerm_resource_group.bootstrap.location
  resource_group_name = azurerm_resource_group.bootstrap.name
  tags                = var.tags
}

resource "azurerm_container_app_environment" "bootstrap" {
  name                       = "cae-${var.name_prefix}-github"
  location                   = azurerm_resource_group.bootstrap.location
  resource_group_name        = azurerm_resource_group.bootstrap.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.bootstrap.id
  tags                       = var.tags
}

resource "azurerm_container_app_job" "orchestrator" {
  count = var.create_container_apps_job ? 1 : 0

  name                         = "caj-${var.name_prefix}-orchestrator"
  location                     = azurerm_resource_group.bootstrap.location
  resource_group_name          = azurerm_resource_group.bootstrap.name
  container_app_environment_id = azurerm_container_app_environment.bootstrap.id
  replica_timeout_in_seconds   = 3600
  replica_retry_limit          = 1

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.job.id]
  }

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name    = "orchestrator"
      image   = var.container_image
      cpu     = var.container_cpu
      memory  = var.container_memory
      command = ["/bin/sh", "-c", "echo bootstrap-ready; sleep 5"]

      env {
        name  = "TF_ROOT"
        value = "/workspace"
      }
    }
  }

  tags = var.tags
}

resource "azurerm_key_vault" "oci" {
  count = var.create_key_vault ? 1 : 0

  name                        = local.key_vault_name_effective
  location                    = azurerm_resource_group.bootstrap.location
  resource_group_name         = azurerm_resource_group.bootstrap.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90
  enable_rbac_authorization   = true
  public_network_access_enabled = true
  tags                        = var.tags
}

resource "azurerm_role_assignment" "job_keyvault_secrets_user" {
  count = var.create_key_vault ? 1 : 0

  scope                = azurerm_key_vault.oci[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.job.principal_id
}

resource "azuread_application_federated_identity_credential" "github_actions" {
  application_id = data.azuread_application.existing_sp.id
  display_name   = "github-actions-${var.github_org}-${var.github_repo}"
  description    = "OIDC federation for GitHub Actions workflow"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = local.github_subject
}
