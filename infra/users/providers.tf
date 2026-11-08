# ===============================================================================
# Provider Configuration - Users Infrastructure
# ===============================================================================
# Auth: Managed Identity (use_msi=true, use_cli=false)
# CI runner uses Container Apps with user-assigned MI, no IMDS.
# ===============================================================================

# ===============================================================================
# mh0 Provider (sub-mh0: Workshop VMs, VNets)
# ===============================================================================

provider "azurerm" {
  alias           = "mh0"
  subscription_id = var.mh0_subscription_id
  tenant_id       = var.tenant_id
  use_cli         = !var.use_msi
  use_msi         = var.use_msi

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
# mhodaa Provider (sub-mhodaa: User ODAA RGs, VNet Peering ODAA side)
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
