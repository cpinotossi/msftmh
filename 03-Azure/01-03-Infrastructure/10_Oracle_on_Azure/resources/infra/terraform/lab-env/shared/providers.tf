# ===============================================================================
# Provider Configuration - Shared Infrastructure
# ===============================================================================
# - azurerm.gallery: Gallery Subscription (Compute Gallery) — sub-mhcore
# - azurerm.odaa:    ODAA Subscription (Shared VNet, Anchors) — sub-mhodaa
# - azapi:           AzAPI provider for Oracle anchors (ODAA sub)
# ===============================================================================

# ===============================================================================
# Gallery Provider (sub-mhcore: Compute Gallery)
# ===============================================================================

provider "azurerm" {
  alias           = "gallery"
  subscription_id = var.gallery_subscription_id

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
}
