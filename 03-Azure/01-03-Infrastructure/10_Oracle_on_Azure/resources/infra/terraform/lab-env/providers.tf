# ===============================================================================
# Provider Configuration - 3 Subscriptions (Shared ODAA VNet)
# ===============================================================================
# This file configures Azure providers for the Oracle on Azure infrastructure:
# - azurerm.mhcore:  Gallery Subscription (Compute Gallery) — sub-mhcore
# - azurerm.mh0:     VM Subscription (Workshop VMs, VNets, DNS) — sub-mh0
# - azurerm.mhodaa:  ODAA Subscription (Shared VNet, Anchors, User RGs) — sub-mhodaa
# - azapi:           AzAPI provider for Oracle network anchors (ODAA sub)
#
# Authentication: Uses ARM_* environment variables or Managed Identity
# For MSI: Set ARM_USE_MSI=true, ARM_CLIENT_ID, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
# For SP:  Set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
# ===============================================================================

# ===============================================================================
# mhcore Provider (sub-mhcore: Compute Gallery)
# ===============================================================================

provider "azurerm" {
  alias           = "mhcore"
  subscription_id = var.mhcore_subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ===============================================================================
# mh0 Provider (sub-mh0: Workshop VMs, VNets)
# ===============================================================================

provider "azurerm" {
  alias           = "mh0"
  subscription_id = var.mh0_subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }
}

# ===============================================================================
# mhodaa Provider (sub-mhodaa: Shared ODAA VNet, Anchors, User RGs)
# ===============================================================================

provider "azurerm" {
  alias           = "mhodaa"
  subscription_id = var.mhodaa_subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ===============================================================================
# AzAPI Provider (ODAA Subscription — for Oracle Resource/Network Anchors)
# ===============================================================================

provider "azapi" {
  subscription_id = var.mhodaa_subscription_id
}

# ===============================================================================
# Azure AD Provider (for Entra ID operations)
# ===============================================================================

provider "azuread" {
}
