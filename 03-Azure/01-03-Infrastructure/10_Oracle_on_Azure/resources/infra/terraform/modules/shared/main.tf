# ===============================================================================
# Shared Module - Azure Compute Gallery and Image Definition
# ===============================================================================
# This module creates shared resources used by all user VMs:
# - Azure Compute Gallery for storing VM images
# - Image Definition for the Oracle workshop VM
# ===============================================================================

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "shared" {
  name     = "rg-shared-${var.prefix}"
  location = var.location
  tags     = var.tags
}

# ===============================================================================
# Azure Compute Gallery
# ===============================================================================

resource "azurerm_shared_image_gallery" "gallery" {
  name                = var.gallery_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  description         = "Shared image gallery for Oracle Workshop VMs"
  tags                = var.tags
}

# ===============================================================================
# Image Definition
# ===============================================================================

resource "azurerm_shared_image" "oracle_workshop" {
  name                      = var.image_name
  gallery_name              = azurerm_shared_image_gallery.gallery.name
  resource_group_name       = azurerm_resource_group.shared.name
  location                  = azurerm_resource_group.shared.location
  os_type                   = "Linux"
  hyper_v_generation        = "V2"
  architecture              = "x64"
  trusted_launch_supported  = true

  identifier {
    publisher = "OracleWorkshop"
    offer     = "oracle-tools"
    sku       = "ubuntu-2404"
  }

  tags = var.tags
}
