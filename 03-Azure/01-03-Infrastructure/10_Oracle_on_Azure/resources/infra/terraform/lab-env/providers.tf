# ===============================================================================
# Provider Configuration - 3 Subscriptions (Shared ODAA VNet)
# ===============================================================================
# This file configures Azure providers for the Oracle on Azure infrastructure:
# - azurerm.gallery: Gallery Subscription (Compute Gallery) — sub-mhcore
# - azurerm.vm:      VM Subscription (Workshop VMs, VNets, DNS) — sub-mh0
# - azurerm.odaa:    ODAA Subscription (Shared VNet, Anchors, User RGs) — sub-mhodaa
# - azapi:           AzAPI provider for Oracle network anchors (ODAA sub)
#
# All users share a single ODAA VNet+Subnet. Each user VM VNet peers to it.
# ===============================================================================

# ===============================================================================
# Gallery Provider (sub-mhcore: Compute Gallery)
# ===============================================================================

provider "azurerm" {
  alias           = "gallery"
  subscription_id = var.gallery_subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret

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
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret

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
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret

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
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

# ===============================================================================
# Azure AD Provider (for Entra ID operations)
# ===============================================================================

provider "azuread" {
  tenant_id     = var.tenant_id
  client_id     = var.client_id
  client_secret = var.client_secret
}
