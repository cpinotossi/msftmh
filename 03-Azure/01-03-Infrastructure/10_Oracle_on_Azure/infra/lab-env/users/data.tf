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
  }
}
