# ===============================================================================
# User ODAA Module - Per-User Resource Group + RBAC
# ===============================================================================
# This module creates per-user ODAA infrastructure:
# - Resource Group (where the user creates Oracle databases via Portal)
# - RBAC: Oracle Database Creator custom role on the user's RG
#
# The shared ODAA VNet/Subnet, DNS, and Anchors are in the shared-odaa module.
# Users create databases in their own RG using the shared networking.
# ===============================================================================

locals {
  user_suffix = format("%02d", var.user_index)
  name_prefix = "user${local.user_suffix}"
}

# ===============================================================================
# Resource Group (per user — user creates DBs here via Portal)
# ===============================================================================

resource "azurerm_resource_group" "odaa" {
  name     = "rg-odaa-${local.name_prefix}"
  location = var.location
  tags     = merge(var.tags, { UserIndex = var.user_index })
}

# ===============================================================================
# RBAC: Entra ID User gets Oracle Database Creator on their RG
# ===============================================================================

resource "azurerm_role_assignment" "odaa_db_creator" {
  count              = var.entra_id_user_object_id != null ? 1 : 0
  scope              = azurerm_resource_group.odaa.id
  role_definition_id = var.odaa_role_definition_id
  principal_id       = var.entra_id_user_object_id
  description        = "Allows Entra ID user to create Oracle ADB/BaseDB in ${azurerm_resource_group.odaa.name}"
}

