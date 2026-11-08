# ===============================================================================
# Provider Configuration - Shared Infrastructure
# ===============================================================================
# Auth: Managed Identity (use_msi=true, use_cli=false)
# CI runner uses Container Apps with user-assigned MI, no IMDS.
# ===============================================================================

# ===============================================================================
# mhcore Provider (sub-mhcore: Compute Gallery)
# ===============================================================================

provider "azurerm" {
  alias           = "mhcore"
  subscription_id = var.mhcore_subscription_id
  tenant_id       = var.tenant_id
  use_cli         = !var.use_msi
  use_msi         = var.use_msi

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ===============================================================================
# mhodaa Provider (sub-mhodaa: Shared ODAA VNet, Anchors, Role Definition)
# ===============================================================================

provider "azurerm" {
  alias           = "mhodaa"
  subscription_id = var.mhodaa_subscription_id
  tenant_id       = var.tenant_id
  use_cli         = !var.use_msi
  use_msi         = var.use_msi

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ===============================================================================
# AzAPI Provider (ODAA Subscription — for Oracle Resource Anchors)
# ===============================================================================

provider "azapi" {
  subscription_id = var.mhodaa_subscription_id
  tenant_id       = var.tenant_id
  use_cli         = !var.use_msi
  use_msi         = var.use_msi
}
