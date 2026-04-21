# ===============================================================================
# GitHub Actions Self-Hosted Runner on Azure Container Apps (AVM Version)
# ===============================================================================
# Uses the Azure Verified Module (AVM) for CI/CD Agents and Runners
# https://github.com/Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners
#
# This configuration:
# - Uses AVM to deploy the GitHub Runner with auto-scaling
# - Keeps existing Managed Identity for multi-subscription RBAC
# - Keeps Storage Account for Terraform state (remote backend)
# ===============================================================================

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "runner" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ===============================================================================
# User-Assigned Managed Identity (kept separate for cross-subscription RBAC)
# ===============================================================================

resource "azurerm_user_assigned_identity" "runner" {
  name                = var.managed_identity_name
  resource_group_name = azurerm_resource_group.runner.name
  location            = azurerm_resource_group.runner.location
  tags                = var.tags
}

# ===============================================================================
# RBAC Assignments - Grant Managed Identity permissions across subscriptions
# ===============================================================================

# Contributor on sub-mhcore (Compute Gallery)
resource "azurerm_role_assignment" "mhcore_contributor" {
  scope                = "/subscriptions/${var.sub_mhcore_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id
}

resource "azurerm_role_assignment" "mhcore_uaa" {
  scope                = "/subscriptions/${var.sub_mhcore_id}"
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id
}

# Contributor on sub-mh0 (Workshop VMs, VNets)
resource "azurerm_role_assignment" "mh0_contributor" {
  scope                = "/subscriptions/${var.sub_mh0_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id
}

resource "azurerm_role_assignment" "mh0_uaa" {
  scope                = "/subscriptions/${var.sub_mh0_id}"
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id
}

# Contributor on sub-mhodaa (ODAA VNets, User RGs)
resource "azurerm_role_assignment" "mhodaa_contributor" {
  scope                = "/subscriptions/${var.sub_mhodaa_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id
}

resource "azurerm_role_assignment" "mhodaa_uaa" {
  scope                = "/subscriptions/${var.sub_mhodaa_id}"
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id
}

# ===============================================================================
# Storage Account for Terraform State (Remote Backend)
# ===============================================================================
# Configured for Private Endpoint access - kept separate from AVM module

data "azurerm_client_config" "current" {}

resource "azurerm_storage_account" "tfstate" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.runner.name
  location                        = azurerm_resource_group.runner.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false     # Policy: key auth disabled
  public_network_access_enabled   = false     # Policy: only PE access allowed
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# Grant Managed Identity access to Terraform state
resource "azurerm_role_assignment" "tfstate_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id
}

# ===============================================================================
# AVM Module - GitHub Runner on Container Apps
# ===============================================================================

module "github_runner" {
  source  = "Azure/avm-ptn-cicd-agents-and-runners/azurerm"
  version = "~> 0.5"

  # Basic configuration
  postfix  = "odaamh"
  location = var.location
  tags     = var.tags

  # Use existing resource group
  resource_group_creation_enabled = false
  resource_group_name             = azurerm_resource_group.runner.name

  # GitHub configuration
  version_control_system_type                  = "github"
  version_control_system_authentication_method = "pat"
  version_control_system_personal_access_token = var.github_pat
  version_control_system_organization          = var.github_owner
  version_control_system_repository            = var.github_repo
  version_control_system_runner_scope          = var.github_runner_scope

  # Runner configuration
  version_control_system_agent_name_prefix = "aca-runner"

  # Use existing Managed Identity (for cross-subscription RBAC)
  user_assigned_managed_identity_creation_enabled = false
  user_assigned_managed_identity_id               = azurerm_user_assigned_identity.runner.id
  user_assigned_managed_identity_client_id        = azurerm_user_assigned_identity.runner.client_id
  user_assigned_managed_identity_principal_id     = azurerm_user_assigned_identity.runner.principal_id

  # VNet configuration — private networking required because Azure Policy
  # enforces publicNetworkAccess=Disabled on storage accounts.
  # The CAE needs VNet integration so the runner can reach the TF state
  # storage via Private Endpoint.
  virtual_network_address_space = var.vnet_address_space
  use_private_networking        = true

  # Container Apps configuration
  container_app_container_cpu    = 2
  container_app_container_memory = "4Gi"
  container_app_max_execution_count = 5
  container_app_min_execution_count = 0

  # Zone redundancy
  use_zone_redundancy = false

  # Additional environment variables for Terraform/Azure
  # Container Apps don't support IMDS (169.254.169.254), so ARM_USE_MSI won't work.
  # Instead, workflows do: az login --identity --client-id $ARM_CLIENT_ID
  # Then Terraform uses Azure CLI auth via ARM_USE_CLI=true (set in workflow).
  container_app_environment_variables = [
    { name = "ARM_TENANT_ID", value = var.tenant_id },
    { name = "ARM_CLIENT_ID", value = azurerm_user_assigned_identity.runner.client_id },
    { name = "ARM_SUBSCRIPTION_ID", value = var.sub_mhcore_id },
    { name = "LABELS", value = "azure,container-apps,terraform" }
  ]

  # Disable telemetry
  enable_telemetry = false

  depends_on = [
    azurerm_resource_group.runner,
    azurerm_user_assigned_identity.runner
  ]
}

# ===============================================================================
# Private Endpoint for Terraform State Storage
# ===============================================================================
# Azure Policy enforces publicNetworkAccess=Disabled and key-auth=false on
# storage accounts. The Container Apps Job runs inside the AVM-created VNet,
# so we create a PE in a dedicated subnet to allow blob access.
# ===============================================================================

resource "azurerm_subnet" "private_endpoints" {
  name                 = var.subnet_private_endpoints_name
  resource_group_name  = azurerm_resource_group.runner.name
  virtual_network_name = module.github_runner.virtual_network_name
  address_prefixes     = [var.subnet_private_endpoints_prefix]
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.runner.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "link-${module.github_runner.virtual_network_name}"
  resource_group_name   = azurerm_resource_group.runner.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = module.github_runner.virtual_network_resource_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "storage" {
  name                = var.storage_private_endpoint_name
  resource_group_name = azurerm_resource_group.runner.name
  location            = azurerm_resource_group.runner.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.storage_account_name}"
    private_connection_resource_id = azurerm_storage_account.tfstate.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

# ===============================================================================
# KEDA Labels Fix (azapi_update_resource)
# ===============================================================================
# The AVM module (Azure/avm-ptn-cicd-agents-and-runners) does not pass custom
# runner labels to the KEDA github-runner scaler metadata. Without labels,
# KEDA only matches the default labels (self-hosted, linux, x64) and ignores
# workflows that require custom labels like "azure,container-apps,terraform".
#
# This is a known gap in the AVM module — it sets the LABELS env var on the
# container (which registers the runner with those labels at GitHub), but does
# NOT include them in the KEDA scaler metadata (which controls auto-scaling).
#
# Workaround: patch the Container Apps Job after AVM deploys it, adding the
# "labels" field to the KEDA scale rule metadata.
# See: https://keda.sh/docs/latest/scalers/github-runner/
# ===============================================================================

resource "terraform_data" "keda_labels" {
  triggers_replace = [module.github_runner.job_resource_id]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "az containerapp job update --name caj-odaamh --resource-group ${azurerm_resource_group.runner.name} --subscription ${var.sub_mhcore_id} --scale-rule-name github-runner --scale-rule-type github-runner --scale-rule-metadata owner=${var.github_owner} repos=${var.github_repo} runnerScope=${var.github_runner_scope} targetWorkflowQueueLength=1 labels=azure,container-apps,terraform --scale-rule-auth personalAccessToken=personal-access-token"
  }

  depends_on = [module.github_runner]
}
