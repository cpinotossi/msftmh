# ===============================================================================
# Test Runner Infrastructure
# ===============================================================================
# Deploys an isolated test VM that validates workshop challenges automatically.
# Always deployed — independent of user_count. Uses Managed Identity for auth.
#
# The RG (rg-test-runner) is owned by infra/github-runner — referenced here as
# a data source. This allows the github-runner MSI to have Contributor at RG
# scope only (no subscription-level Contributor on sub-mhcore).
#
# Resources:
# - VNet, Subnet, NSG in rg-test-runner (sub-mhcore)
# - VM with System-Assigned Managed Identity (same Gallery image as user VMs)
# - VNet Peering to shared ODAA VNet (ADB connectivity)
# - Private DNS Zone + VNet link (test-owned, no user side effects)
# - RBAC: Reader on sub-mh0 + sub-mhodaa + rg-test-runner, Custom Role on rg-odaa-shared
# ===============================================================================

locals {
  shared  = data.terraform_remote_state.shared.outputs
  vm_cidr = "10.200.0.0/24"
}

# ===============================================================================
# Remote State (shared infrastructure outputs)
# ===============================================================================

data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    storage_account_name = var.tf_state_storage
    container_name       = var.tf_state_container
    key                  = "shared.tfstate"
    resource_group_name  = var.tf_state_rg
    use_msi              = true
    use_azuread_auth     = true
  }
}

# ===============================================================================
# Resource Group
# ===============================================================================

data "azurerm_resource_group" "test" {
  provider = azurerm.mhcore
  name     = "rg-test-runner"
}

# ===============================================================================
# Network (VNet + Subnet + NSG)
# ===============================================================================

resource "azurerm_network_security_group" "test" {
  provider            = azurerm.mhcore
  name                = "nsg-test-runner"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.test.name
  tags                = var.tags
}

resource "azurerm_virtual_network" "test" {
  provider            = azurerm.mhcore
  name                = "vnet-test-runner"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.test.name
  address_space       = [local.vm_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "test" {
  provider             = azurerm.mhcore
  name                 = "snet-test-runner"
  resource_group_name  = data.azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = [local.vm_cidr]
}

resource "azurerm_subnet_network_security_group_association" "test" {
  provider                  = azurerm.mhcore
  subnet_id                 = azurerm_subnet.test.id
  network_security_group_id = azurerm_network_security_group.test.id
}

# ===============================================================================
# SSH Key (for emergency access only)
# ===============================================================================

resource "tls_private_key" "test" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ===============================================================================
# NIC
# ===============================================================================

resource "azurerm_network_interface" "test" {
  provider            = azurerm.mhcore
  name                = "nic-test-runner"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.test.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ===============================================================================
# Virtual Machine
# ===============================================================================

resource "azurerm_linux_virtual_machine" "test" {
  provider            = azurerm.mhcore
  name                = "vm-test-runner"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.test.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  network_interface_ids = [azurerm_network_interface.test.id]

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.test.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_id = "${local.shared.image_id}/versions/${var.vm_image_version}"

  custom_data = base64encode(file("${path.module}/cloud-init.yaml"))
}

# ===============================================================================
# VNet Peering — Test Runner <-> Shared ODAA VNet
# ===============================================================================

resource "azurerm_virtual_network_peering" "test_to_odaa" {
  provider                  = azurerm.mhcore
  name                      = "peer-test-runner-to-odaa"
  resource_group_name       = data.azurerm_resource_group.test.name
  virtual_network_name      = azurerm_virtual_network.test.name
  remote_virtual_network_id = local.shared.odaa_vnet_id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "odaa_to_test" {
  provider                  = azurerm.mhodaa
  name                      = "peer-odaa-to-test-runner"
  resource_group_name       = local.shared.odaa_resource_group_name
  virtual_network_name      = local.shared.odaa_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.test.id
  allow_forwarded_traffic   = true
}

# ===============================================================================
# RBAC — Managed Identity permissions
# ===============================================================================

# Reader on sub-mh0 (user VMs, VNets, NSGs)
resource "azurerm_role_assignment" "reader_mh0" {
  provider             = azurerm.mh0
  scope                = "/subscriptions/${var.mh0_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.test.identity[0].principal_id
}

# Reader on sub-mhodaa (ODAA resources)
resource "azurerm_role_assignment" "reader_mhodaa" {
  provider             = azurerm.mhodaa
  scope                = "/subscriptions/${var.mhodaa_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.test.identity[0].principal_id
}

# Reader on rg-test-runner (own RG, DNS zone — no subscription scope)
resource "azurerm_role_assignment" "reader_mhcore" {
  provider             = azurerm.mhcore
  scope                = data.azurerm_resource_group.test.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.test.identity[0].principal_id
}

# Custom role "Oracle Database Creator" on rg-odaa-shared — same as workshop users
# ADB setup runs via GitHub OIDC SP (Contributor); VM MI only needs user-level access.
resource "azurerm_role_assignment" "odaa_db_creator" {
  provider           = azurerm.mhodaa
  scope              = "/subscriptions/${var.mhodaa_subscription_id}/resourceGroups/${local.shared.odaa_resource_group_name}"
  role_definition_id = local.shared.odaa_role_definition_resource_id
  principal_id       = azurerm_linux_virtual_machine.test.identity[0].principal_id
}

# ===============================================================================
# Private DNS Zone (test-owned, isolated from user resources)
# ===============================================================================

resource "azurerm_private_dns_zone" "test" {
  provider            = azurerm.mhcore
  name                = "adb.eu-paris-1.oraclecloud.com"
  resource_group_name = data.azurerm_resource_group.test.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "test" {
  provider              = azurerm.mhcore
  name                  = "link-test-runner"
  resource_group_name   = data.azurerm_resource_group.test.name
  private_dns_zone_name = azurerm_private_dns_zone.test.name
  virtual_network_id    = azurerm_virtual_network.test.id
  registration_enabled  = false
  tags                  = var.tags
}

# ===============================================================================
# State Migration: count removal (from [0] to non-indexed)
# These moved blocks handle the one-time migration from count-based resources
# to always-deployed resources. Safe to remove after first successful apply.
# ===============================================================================

moved {
  from = azurerm_network_security_group.test[0]
  to   = azurerm_network_security_group.test
}

moved {
  from = azurerm_virtual_network.test[0]
  to   = azurerm_virtual_network.test
}

moved {
  from = azurerm_subnet.test[0]
  to   = azurerm_subnet.test
}

moved {
  from = azurerm_subnet_network_security_group_association.test[0]
  to   = azurerm_subnet_network_security_group_association.test
}

moved {
  from = tls_private_key.test[0]
  to   = tls_private_key.test
}

moved {
  from = azurerm_network_interface.test[0]
  to   = azurerm_network_interface.test
}

moved {
  from = azurerm_linux_virtual_machine.test[0]
  to   = azurerm_linux_virtual_machine.test
}

moved {
  from = azurerm_virtual_network_peering.test_to_odaa[0]
  to   = azurerm_virtual_network_peering.test_to_odaa
}

moved {
  from = azurerm_virtual_network_peering.odaa_to_test[0]
  to   = azurerm_virtual_network_peering.odaa_to_test
}

moved {
  from = azurerm_role_assignment.reader_mh0[0]
  to   = azurerm_role_assignment.reader_mh0
}

moved {
  from = azurerm_role_assignment.reader_mhodaa[0]
  to   = azurerm_role_assignment.reader_mhodaa
}
