# ===============================================================================
# Provider Configuration - Users Infrastructure
# ===============================================================================
# Auth: Managed Identity (use_msi=true, use_cli=false)
# CI runner uses Container Apps with user-assigned MI, no IMDS.
# ===============================================================================

# ===============================================================================
# VM Provider (sub-mh0: Workshop VMs, VNets)
# ===============================================================================

provider "azurerm" {
  alias           = "vm"
  subscription_id = var.vm_subscription_id
  use_cli         = false
  use_msi         = true

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
# ODAA Provider (sub-mhodaa: User ODAA RGs, VNet Peering ODAA side)
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
