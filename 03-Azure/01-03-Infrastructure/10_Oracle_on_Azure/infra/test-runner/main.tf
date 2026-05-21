# ===============================================================================
# Test Runner Infrastructure
# ===============================================================================
# Deploys an isolated test VM that validates workshop challenges automatically.
# Only deployed when user_count > 0. Uses Managed Identity for auth.
#
# Resources (all conditional on user_count > 0):
# - RG, VNet, Subnet, NSG in sub-mhcore
# - VM with System-Assigned Managed Identity
# - VNet Peering to shared ODAA VNet (ADB connectivity)
# - Private DNS Zone link (ADB name resolution)
# - RBAC: Reader on sub-mh0 and sub-mhodaa
# ===============================================================================

locals {
  deploy  = var.user_count > 0 ? 1 : 0
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

resource "azurerm_resource_group" "test" {
  provider = azurerm.mhcore
  count    = local.deploy
  name     = "rg-test-runner"
  location = var.location
  tags     = var.tags
}

# ===============================================================================
# Network (VNet + Subnet + NSG)
# ===============================================================================

resource "azurerm_network_security_group" "test" {
  provider            = azurerm.mhcore
  count               = local.deploy
  name                = "nsg-test-runner"
  location            = var.location
  resource_group_name = azurerm_resource_group.test[0].name
  tags                = var.tags
}

resource "azurerm_virtual_network" "test" {
  provider            = azurerm.mhcore
  count               = local.deploy
  name                = "vnet-test-runner"
  location            = var.location
  resource_group_name = azurerm_resource_group.test[0].name
  address_space       = [local.vm_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "test" {
  provider             = azurerm.mhcore
  count                = local.deploy
  name                 = "snet-test-runner"
  resource_group_name  = azurerm_resource_group.test[0].name
  virtual_network_name = azurerm_virtual_network.test[0].name
  address_prefixes     = [local.vm_cidr]
}

resource "azurerm_subnet_network_security_group_association" "test" {
  provider                  = azurerm.mhcore
  count                     = local.deploy
  subnet_id                 = azurerm_subnet.test[0].id
  network_security_group_id = azurerm_network_security_group.test[0].id
}

# ===============================================================================
# SSH Key (for emergency access only)
# ===============================================================================

resource "tls_private_key" "test" {
  count     = local.deploy
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ===============================================================================
# NIC
# ===============================================================================

resource "azurerm_network_interface" "test" {
  provider            = azurerm.mhcore
  count               = local.deploy
  name                = "nic-test-runner"
  location            = var.location
  resource_group_name = azurerm_resource_group.test[0].name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

# ===============================================================================
# Virtual Machine
# ===============================================================================

resource "azurerm_linux_virtual_machine" "test" {
  provider            = azurerm.mhcore
  count               = local.deploy
  name                = "vm-test-runner"
  location            = var.location
  resource_group_name = azurerm_resource_group.test[0].name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  network_interface_ids = [azurerm_network_interface.test[0].id]

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.test[0].public_key_openssh
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
  count                     = local.deploy
  name                      = "peer-test-runner-to-odaa"
  resource_group_name       = azurerm_resource_group.test[0].name
  virtual_network_name      = azurerm_virtual_network.test[0].name
  remote_virtual_network_id = local.shared.odaa_vnet_id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "odaa_to_test" {
  provider                  = azurerm.mhodaa
  count                     = local.deploy
  name                      = "peer-odaa-to-test-runner"
  resource_group_name       = local.shared.odaa_resource_group_name
  virtual_network_name      = local.shared.odaa_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.test[0].id
  allow_forwarded_traffic   = true
}

# ===============================================================================
# RBAC — Managed Identity permissions
# ===============================================================================

# Reader on sub-mh0 (user VMs, VNets, NSGs)
resource "azurerm_role_assignment" "reader_mh0" {
  provider             = azurerm.mh0
  count                = local.deploy
  scope                = "/subscriptions/${var.mh0_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.test[0].identity[0].principal_id
}

# Reader on sub-mhodaa (ODAA resources)
resource "azurerm_role_assignment" "reader_mhodaa" {
  provider             = azurerm.mhodaa
  count                = local.deploy
  scope                = "/subscriptions/${var.mhodaa_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.test[0].identity[0].principal_id
}
