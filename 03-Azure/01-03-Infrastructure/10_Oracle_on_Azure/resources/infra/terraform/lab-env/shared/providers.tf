# ===============================================================================
# Provider Configuration - Shared Infrastructure
# ===============================================================================
# Auth: Managed Identity (use_msi=true, use_cli=false)
# CI runner uses Container Apps with user-assigned MI, no IMDS.
# ===============================================================================

# ===============================================================================
# Gallery Provider (sub-mhcore: Compute Gallery)
# ===============================================================================

provider "azurerm" {
  alias           = "gallery"
  subscription_id = var.gallery_subscription_id
  use_cli         = false
  use_msi         = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ===============================================================================
# ODAA Provider (sub-mhodaa: Shared ODAA VNet, Anchors, Role Definition)
# ===============================================================================

provider "azurerm" {
  alias           = "odaa"
  subscription_id = var.odaa_subscription_id
  use_cli         = false
  use_msi         = true

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
  subscription_id = var.odaa_subscription_id
  use_cli         = false
  use_msi         = true
}
