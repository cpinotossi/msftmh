# ===============================================================================
# User VM Module - Virtual Machine Infrastructure per User
# ===============================================================================
# This module creates VM infrastructure for a single workshop user:
# - Resource Group
# - Virtual Network with Subnet
# - Network Interface
# - Virtual Machine (from Compute Gallery image)
# - Private DNS Zone Link
# ===============================================================================

locals {
  user_suffix = format("%02d", var.user_index)
  name_prefix = "user${local.user_suffix}"
  vm_subnet_cidr      = cidrsubnet(var.vnet_cidr, 1, 0)
  bastion_subnet_cidr = cidrsubnet(var.vnet_cidr, 2, 2)
}

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "vm" {
  name     = "rg-vm-${local.name_prefix}"
  location = var.location
  tags     = merge(var.tags, { UserIndex = var.user_index })
}

# ===============================================================================
# Virtual Network
# ===============================================================================

resource "azurerm_virtual_network" "vm" {
  name                = "vnet-vm-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "vm" {
  name                            = "snet-vm-${local.name_prefix}"
  resource_group_name             = azurerm_resource_group.vm.name
  virtual_network_name            = azurerm_virtual_network.vm.name
  address_prefixes                = [local.vm_subnet_cidr]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.vm.name
  virtual_network_name = azurerm_virtual_network.vm.name
  address_prefixes     = [local.bastion_subnet_cidr]
}

# ===============================================================================
# NAT Gateway (for outbound internet access)
# ===============================================================================

resource "azurerm_public_ip" "nat" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "pip-nat-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "vm" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "nat-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "vm" {
  count                = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.vm[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "vm" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.vm.id
  nat_gateway_id = azurerm_nat_gateway.vm[0].id
}

# ===============================================================================
# Network Security Group
# ===============================================================================

resource "azurerm_network_security_group" "vm" {
  name                = "nsg-vm-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  tags                = var.tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# ===============================================================================
# Public IP (Optional - for direct SSH access)
# ===============================================================================

resource "azurerm_public_ip" "vm" {
  count               = var.create_public_ip ? 1 : 0
  name                = "pip-vm-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-bas-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "vm" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  sku                 = var.bastion_sku
  tunneling_enabled   = var.bastion_sku != "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# ===============================================================================
# Network Interface
# ===============================================================================

resource "azurerm_network_interface" "vm" {
  name                = "nic-vm-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.create_public_ip ? azurerm_public_ip.vm[0].id : null
  }

  # Explicit depends_on ensures proper destroy ordering:
  # NIC must be destroyed BEFORE subnet, public IP, and NSG association.
  # The conditional public_ip_address_id reference may not create a strong
  # implicit dependency in all cases, and the NSG association must be removed
  # before Azure fully releases the subnet for NIC deletion.
  depends_on = [
    azurerm_subnet.vm,
    azurerm_public_ip.vm,
    azurerm_subnet_network_security_group_association.vm,
  ]
}

# ===============================================================================
# Virtual Machine
# ===============================================================================

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-${local.name_prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = merge(var.tags, { UserIndex = var.user_index })

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  # System-assigned managed identity required for Entra ID login
  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  # Use image from Compute Gallery if provided, otherwise use Ubuntu
  dynamic "source_image_reference" {
    for_each = var.vm_image_id == null ? [1] : []
    content {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
      version   = "latest"
    }
  }

  source_image_id = var.vm_image_id

  # Prevent accidental deletion
  lifecycle {
    ignore_changes = [
      tags["CreatedDate"]
    ]
  }
}

# ===============================================================================
# Entra ID (Azure AD) Login Extension
# ===============================================================================

resource "azurerm_virtual_machine_extension" "aad_login" {
  count                      = var.enable_entra_id_login ? 1 : 0
  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  tags = var.tags
}

# ===============================================================================
# RBAC: Entra ID User Login Permission
# ===============================================================================

resource "azurerm_role_assignment" "vm_rg_reader" {
  count                = var.enable_entra_id_login && var.entra_id_user_object_id != null ? 1 : 0
  scope                = azurerm_resource_group.vm.id
  role_definition_name = "Reader"
  principal_id         = var.entra_id_user_object_id
  description          = "Allows Entra ID user to see RG ${azurerm_resource_group.vm.name} in the portal"
}

resource "azurerm_role_assignment" "dns_zone_contributor" {
  count                = var.enable_entra_id_login && var.entra_id_user_object_id != null && var.create_dns_link && !local.use_existing_dns_zone ? 1 : 0
  scope                = azurerm_private_dns_zone.odaa[0].id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = var.entra_id_user_object_id
  description          = "Allows Entra ID user to manage Private DNS Zone in RG ${azurerm_resource_group.vm.name}"
}

resource "azurerm_role_assignment" "vm_user_login" {
  count                = var.enable_entra_id_login && var.entra_id_user_object_id != null ? 1 : 0
  scope                = azurerm_linux_virtual_machine.vm.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = var.entra_id_user_object_id
  description          = "Allows Entra ID user to login to VM ${azurerm_linux_virtual_machine.vm.name}"
}

# Optional: Admin login (sudo access)
resource "azurerm_role_assignment" "vm_admin_login" {
  count                = var.enable_entra_id_login && var.entra_id_user_object_id != null && var.entra_id_admin_login ? 1 : 0
  scope                = azurerm_linux_virtual_machine.vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = var.entra_id_user_object_id
  description          = "Allows Entra ID user admin (sudo) access to VM ${azurerm_linux_virtual_machine.vm.name}"
}

# ===============================================================================
# Private DNS Zone Link (optional — links existing DNS zone to this VM's VNet)
# ===============================================================================
# In the shared ODAA architecture, the DNS zone lives in the shared-odaa module.
# Links are created at root level with the ODAA provider.
# Set create_dns_link = false when using shared architecture.
# ===============================================================================

locals {
  use_existing_dns_zone = var.dns_zone_resource_group != null && trimspace(var.dns_zone_resource_group) != ""
}

resource "azurerm_private_dns_zone" "odaa" {
  count               = var.create_dns_link && !local.use_existing_dns_zone ? 1 : 0
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.vm.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "odaa" {
  count                 = var.create_dns_link ? 1 : 0
  name                  = "link-${local.name_prefix}"
  resource_group_name   = local.use_existing_dns_zone ? var.dns_zone_resource_group : azurerm_resource_group.vm.name
  private_dns_zone_name = local.use_existing_dns_zone ? var.dns_zone_name : azurerm_private_dns_zone.odaa[0].name
  virtual_network_id    = azurerm_virtual_network.vm.id
  registration_enabled  = false
  tags                  = var.tags

  # Explicit depends_on ensures proper destroy ordering:
  # DNS link must be destroyed BEFORE the DNS zone and the VNet.
  # The conditional private_dns_zone_name reference (ternary with count)
  # may not create a strong implicit dependency in all code paths.
  depends_on = [
    azurerm_private_dns_zone.odaa,
    azurerm_virtual_network.vm,
  ]
}
