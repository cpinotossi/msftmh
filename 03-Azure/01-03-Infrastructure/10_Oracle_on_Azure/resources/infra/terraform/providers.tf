# ===============================================================================
# Provider Configuration - Simplified (2 Subscriptions)
# ===============================================================================
# This file configures Azure providers for the Oracle on Azure infrastructure:
# - azurerm.vm:   VM Subscription (Workshop VMs, Compute Gallery)
# - azurerm.odaa: ODAA Subscription (Oracle Database@Azure)
# ===============================================================================

# ===============================================================================
# Default Provider (VM Subscription)
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
# ODAA Provider (Oracle Database@Azure Subscription)
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
# Azure AD Provider (for Entra ID operations)
# ===============================================================================

provider "azuread" {
  tenant_id     = var.tenant_id
  client_id     = var.client_id
  client_secret = var.client_secret
}
