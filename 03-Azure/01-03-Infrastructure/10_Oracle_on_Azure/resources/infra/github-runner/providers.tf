# ===============================================================================
# Provider Configuration - GitHub Runner Infrastructure
# ===============================================================================
# Deploys to sub-mhcore (Compute Gallery subscription)
# ===============================================================================

provider "azurerm" {
  subscription_id     = var.sub_mhcore_id
  tenant_id           = var.tenant_id
  use_cli             = true
  storage_use_azuread = true  # Use Azure AD auth for storage (required when key auth disabled)

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "random" {}
