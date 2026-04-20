# ===============================================================================
# Provider Configuration - Users Infrastructure
# ===============================================================================
# - azurerm.vm:   VM Subscription (Workshop VMs, VNets, DNS) — sub-mh0
# - azurerm.odaa: ODAA Subscription (User ODAA RGs, Peering) — sub-mhodaa
# ===============================================================================

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
# ODAA Provider (sub-mhodaa: User ODAA RGs, VNet Peering ODAA side)
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
