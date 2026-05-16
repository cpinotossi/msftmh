# ===============================================================================
# Backend Configuration - Shared Infrastructure State
# ===============================================================================
# Storage account, container, and RG are passed via -backend-config in CI.
# ===============================================================================

terraform {
  backend "azurerm" {
    key = "shared.tfstate"
  }
}
