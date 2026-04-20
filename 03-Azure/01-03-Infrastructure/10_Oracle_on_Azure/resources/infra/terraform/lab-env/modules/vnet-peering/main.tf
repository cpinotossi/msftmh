# ===============================================================================
# VNet Peering Module - Main Configuration
# ===============================================================================
# This module creates bidirectional VNet peering between VM and ODAA networks
# across different Azure subscriptions.
# ===============================================================================

terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.vm, azurerm.odaa]
    }
  }
}

# ===============================================================================
# VNet Peering: VM to ODAA
# ===============================================================================

resource "azurerm_virtual_network_peering" "vm_to_odaa" {
  provider                  = azurerm.vm
  name                      = var.peering_suffix != "" ? "peer-vm-to-odaa-${var.peering_suffix}" : "peer-vm-to-odaa"
  resource_group_name       = var.vm_resource_group
  virtual_network_name      = var.vm_vnet_name
  remote_virtual_network_id = var.odaa_vnet_id

  # Peering settings
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  lifecycle {
    create_before_destroy = false
  }
}

# ===============================================================================
# VNet Peering: ODAA to VM
# ===============================================================================

resource "azurerm_virtual_network_peering" "odaa_to_vm" {
  provider                  = azurerm.odaa
  name                      = var.peering_suffix != "" ? "peer-odaa-to-vm-${var.peering_suffix}" : "peer-odaa-to-vm"
  resource_group_name       = var.odaa_resource_group
  virtual_network_name      = var.odaa_vnet_name
  remote_virtual_network_id = var.vm_vnet_id

  # Peering settings
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  lifecycle {
    create_before_destroy = false
  }
}