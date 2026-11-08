# ===============================================================================
# Data Sources - Read Shared Infrastructure Outputs
# ===============================================================================
# Reads outputs from the shared/ project's state file to get:
# - image_id (Compute Gallery)
# - ODAA VNet IDs/names (for peering)
# - Role definition ID (for user RBAC)
# ===============================================================================

data "terraform_remote_state" "shared" {
  backend = "azurerm"

  config = {
    storage_account_name = var.tf_state_storage
    container_name       = var.tf_state_container
    resource_group_name  = var.tf_state_rg
    key                  = "shared.tfstate"
    use_azuread_auth     = var.tf_state_use_azuread_auth
    subscription_id      = var.mh0_subscription_id
    tenant_id            = var.tenant_id
    use_msi              = var.use_msi
  }
}

data "terraform_remote_state" "identity" {
  backend = "azurerm"
  config = {
    subscription_id      = var.mh0_subscription_id
    tenant_id            = var.tenant_id
    storage_account_name = var.tf_state_storage
    container_name       = var.tf_state_container
    resource_group_name  = var.tf_state_rg
    key                  = "identity.tfstate"
    use_azuread_auth     = var.tf_state_use_azuread_auth
    use_msi              = var.use_msi
  }
}
