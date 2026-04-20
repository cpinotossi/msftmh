provider "azurerm" {
  subscription_id = var.bootstrap_subscription_id
  tenant_id       = var.tenant_id

  features {}
}

provider "azuread" {
  tenant_id = var.tenant_id
}
