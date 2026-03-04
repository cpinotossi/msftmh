# ===============================================================================
# User ODAA Module - Oracle Database@Azure Infrastructure per User
# ===============================================================================
# This module creates ODAA infrastructure for a single workshop user:
# - Resource Group
# - Virtual Network with Oracle delegated Subnet
# - (optional) Autonomous Database (ADB) when db_type = "adb"
# - (optional) Exadata Infrastructure + Cloud VM Cluster when db_type = "basedb"
# ===============================================================================

locals {
  user_suffix = format("%02d", var.user_index)
  name_prefix = "user${local.user_suffix}"
}

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "odaa" {
  name     = "rg-odaa-${local.name_prefix}"
  location = var.location
  tags     = merge(var.tags, { UserIndex = var.user_index })
}

# ===============================================================================
# Virtual Network
# ===============================================================================

resource "azurerm_virtual_network" "odaa" {
  name                = "vnet-odaa-${local.name_prefix}"
  location            = azurerm_resource_group.odaa.location
  resource_group_name = azurerm_resource_group.odaa.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# ===============================================================================
# Subnet with Oracle Delegation
# ===============================================================================

resource "azurerm_subnet" "odaa" {
  name                 = "snet-odaa-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.odaa.name
  virtual_network_name = azurerm_virtual_network.odaa.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 0)] # /24 subnet

  default_outbound_access_enabled = true

  delegation {
    name = "oracle-delegation"
    service_delegation {
      name = "Oracle.Database/networkAttachments"
      actions = [
        "Microsoft.Network/networkinterfaces/*",
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }

  # Prevent deletion while Oracle databases might be using this subnet
  lifecycle {
    prevent_destroy = false
  }
}

# ===============================================================================
# Autonomous Database (ADB) - per User
# ===============================================================================
# Created when db_type = "adb"
# Serverless Autonomous Database with configurable compute and storage.
# ===============================================================================

resource "azurerm_oracle_autonomous_database" "adb" {
  count = var.db_type == "adb" ? 1 : 0

  name                = "adbodaa${local.name_prefix}"
  resource_group_name = azurerm_resource_group.odaa.name
  location            = var.location
  display_name        = "adbodaa${local.name_prefix}"

  # Network
  subnet_id          = azurerm_subnet.odaa.id
  virtual_network_id = azurerm_virtual_network.odaa.id

  # Database Configuration
  admin_password                   = var.adb_admin_password
  db_version                       = var.adb_db_version
  db_workload                      = var.adb_db_workload
  compute_model                    = var.adb_compute_model
  compute_count                    = var.adb_compute_count
  data_storage_size_in_tbs         = var.adb_data_storage_size_in_tbs
  character_set                    = var.adb_character_set
  national_character_set           = var.adb_national_character_set
  license_model                    = var.byol ? "BringYourOwnLicense" : "LicenseIncluded"
  auto_scaling_enabled             = var.adb_auto_scaling_enabled
  auto_scaling_for_storage_enabled = var.adb_auto_scaling_for_storage_enabled
  backup_retention_period_in_days  = var.adb_backup_retention_period_in_days
  mtls_connection_required         = var.adb_mtls_connection_required

  tags = merge(var.tags, { UserIndex = var.user_index })
}

# ===============================================================================
# Base Database - Exadata Infrastructure
# ===============================================================================
# Created when db_type = "basedb"
# Provisions Exadata Infrastructure and Cloud VM Cluster.
# Note: Exadata provisioning takes 2-4 hours.
# ===============================================================================

resource "azurerm_oracle_exadata_infrastructure" "basedb" {
  count = var.db_type == "basedb" ? 1 : 0

  name                = "exa-odaa-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.odaa.name
  location            = var.location
  display_name        = "exa-odaa-${local.name_prefix}"

  shape         = var.basedb_shape
  compute_count = var.basedb_compute_count
  storage_count = var.basedb_storage_count
  zones         = var.basedb_zones

  tags = merge(var.tags, { UserIndex = var.user_index })
}

# Retrieve DB servers from Exadata Infrastructure (available after provisioning)
data "azurerm_oracle_db_servers" "basedb" {
  count = var.db_type == "basedb" ? 1 : 0

  cloud_exadata_infrastructure_name = azurerm_oracle_exadata_infrastructure.basedb[0].name
  resource_group_name               = azurerm_resource_group.odaa.name

  depends_on = [azurerm_oracle_exadata_infrastructure.basedb]
}

# ===============================================================================
# Base Database - Cloud VM Cluster
# ===============================================================================

resource "azurerm_oracle_cloud_vm_cluster" "basedb" {
  count = var.db_type == "basedb" ? 1 : 0

  name                           = "vmcl-odaa-${local.name_prefix}"
  resource_group_name            = azurerm_resource_group.odaa.name
  location                       = var.location
  display_name                   = "vmcl-odaa-${local.name_prefix}"
  cloud_exadata_infrastructure_id = azurerm_oracle_exadata_infrastructure.basedb[0].id

  # Compute
  cpu_core_count              = var.basedb_cpu_core_count
  data_storage_size_in_tbs    = var.basedb_data_storage_size_in_tbs
  db_node_storage_size_in_gbs = var.basedb_db_node_storage_size_in_gbs
  memory_size_in_gbs          = var.basedb_memory_size_in_gbs
  gi_version                  = var.basedb_gi_version
  hostname                    = "vm${local.user_suffix}"
  license_model               = var.byol ? "BringYourOwnLicense" : "LicenseIncluded"
  ssh_public_keys             = var.basedb_ssh_public_keys
  db_servers                  = data.azurerm_oracle_db_servers.basedb[0].db_servers[*].ocid

  # Network
  subnet_id          = azurerm_subnet.odaa.id
  virtual_network_id = azurerm_virtual_network.odaa.id

  tags = merge(var.tags, { UserIndex = var.user_index })

  depends_on = [data.azurerm_oracle_db_servers.basedb]
}
