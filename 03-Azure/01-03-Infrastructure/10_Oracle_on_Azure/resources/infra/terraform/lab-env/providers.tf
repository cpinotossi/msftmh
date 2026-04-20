# ===============================================================================
# Provider Configuration - 3 Subscriptions (Shared ODAA VNet)
# ===============================================================================
# This file configures Azure providers for the Oracle on Azure infrastructure:
# - azurerm.gallery: Gallery Subscription (Compute Gallery) — sub-mhcore
# - azurerm.vm:      VM Subscription (Workshop VMs, VNets, DNS) — sub-mh0
# - azurerm.odaa:    ODAA Subscription (Shared VNet, Anchors, User RGs) — sub-mhodaa
# - azapi:           AzAPI provider for Oracle network anchors (ODAA sub)
#
# Authentication: Uses ARM_* environment variables or Managed Identity
# For MSI: Set ARM_USE_MSI=true, ARM_CLIENT_ID, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
# For SP:  Set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
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
# VM Provider (sub-mh0: Workshop VMs, VNets)
# ===============================================================================

provider "azurerm" {
  alias           = "vm"
  subscription_id = var.vm_subscription_id

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
# ODAA Provider (sub-mhodaa: Shared ODAA VNet, Anchors, User RGs)
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
# AzAPI Provider (ODAA Subscription — for Oracle Resource/Network Anchors)
# ===============================================================================

provider "azapi" {
  subscription_id = var.odaa_subscription_id
}

# ===============================================================================
# Azure AD Provider (for Entra ID operations)
# ===============================================================================

provider "azuread" {
}
