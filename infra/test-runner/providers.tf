# ===============================================================================
# Provider Configuration - Test Runner
# ===============================================================================

provider "azurerm" {
  subscription_id = var.mhcore_subscription_id
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
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }
}

provider "azurerm" {
  alias           = "mh0"
  subscription_id = var.mh0_subscription_id
  tenant_id       = var.tenant_id
  use_cli         = !var.use_msi
  use_msi         = var.use_msi

  features {}
}

provider "azurerm" {
  alias           = "mhodaa"
  subscription_id = var.mhodaa_subscription_id
  tenant_id       = var.tenant_id
  use_cli         = !var.use_msi
  use_msi         = var.use_msi

  features {}
}
