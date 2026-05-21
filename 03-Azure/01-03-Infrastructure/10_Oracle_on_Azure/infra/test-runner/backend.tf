# ===============================================================================
# Backend Configuration - Test Runner State
# ===============================================================================

terraform {
  backend "azurerm" {
    key = "test-runner.tfstate"
  }
}
