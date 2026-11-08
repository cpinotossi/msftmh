data "terraform_remote_state" "identity" {
  backend = "azurerm"
  config = {
    subscription_id      = var.mhcore_subscription_id
    tenant_id            = var.tenant_id
    storage_account_name = var.tf_state_storage
    resource_group_name  = var.tf_state_rg
    container_name       = var.tf_state_container
    key                  = "identity.tfstate"
    use_azuread_auth     = true
    use_msi              = var.use_msi
  }
}

locals {
  workshop_group_id = var.odaa_user_group_id != null ? var.odaa_user_group_id : data.terraform_remote_state.identity.outputs.group_id
  spoke_cidrs       = [for i in range(1, var.user_count + 1) : "10.0.${i}.0/24"]
  client_cidrs      = concat(local.spoke_cidrs, ["10.200.0.0/24"])
  oracle_cidr       = cidrsubnet(var.odaa_vnet_cidr, 8, 0)
}

resource "azurerm_resource_group" "hub" {
  provider = azurerm.mhcore
  name     = "rg-workshop-hub"
  location = var.location
  tags     = var.tags

  lifecycle {
    precondition {
      condition     = var.mhcore_subscription_id != var.mhodaa_subscription_id
      error_message = "Hub and Oracle resources must use separate subscriptions."
    }
  }
}

resource "azurerm_virtual_network" "hub" {
  provider            = azurerm.mhcore
  name                = "vnet-workshop-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = [var.hub_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "hub" {
  provider             = azurerm.mhcore
  for_each             = toset(["AzureFirewallSubnet", "AzureBastionSubnet", "snet-dns-inbound", "snet-dns-outbound"])
  name                 = each.key
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes = [
    cidrsubnet(var.hub_vnet_cidr, 10, index(
      ["AzureFirewallSubnet", "AzureBastionSubnet", "snet-dns-inbound", "snet-dns-outbound"], each.key
    ))
  ]
  default_outbound_access_enabled = false

  dynamic "delegation" {
    for_each = startswith(each.key, "snet-dns-") ? [1] : []
    content {
      name = "dns-resolver"
      service_delegation {
        name    = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

resource "azurerm_private_dns_resolver" "hub" {
  provider            = azurerm.mhcore
  name                = "dns-workshop-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  virtual_network_id  = azurerm_virtual_network.hub.id
  tags                = var.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "hub" {
  provider                = azurerm.mhcore
  name                    = "dns-inbound"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.hub.id
  ip_configurations {
    private_ip_allocation_method = "Static"
    private_ip_address           = cidrhost(azurerm_subnet.hub["snet-dns-inbound"].address_prefixes[0], 4)
    subnet_id                    = azurerm_subnet.hub["snet-dns-inbound"].id
  }
  tags = var.tags
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "hub" {
  provider                = azurerm.mhcore
  name                    = "dns-outbound"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.hub.id
  subnet_id               = azurerm_subnet.hub["snet-dns-outbound"].id
  tags                    = var.tags
}

resource "azurerm_public_ip" "firewall" {
  provider            = azurerm.mhcore
  name                = "pip-workshop-firewall"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "hub" {
  provider            = azurerm.mhcore
  name                = "policy-workshop-firewall"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "Standard"
  dns {
    proxy_enabled = true
    servers       = [azurerm_private_dns_resolver_inbound_endpoint.hub.ip_configurations[0].private_ip_address]
  }
  tags = var.tags
}

resource "azurerm_firewall" "hub" {
  provider            = azurerm.mhcore
  name                = "fw-workshop-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
  tags = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "hub" {
  provider           = azurerm.mhcore
  name               = "workshop-connectivity"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 100

  network_rule_collection {
    name     = "deny-client-to-client"
    priority = 100
    action   = "Deny"
    rule {
      name                  = "isolated-spokes"
      protocols             = ["Any"]
      source_addresses      = local.client_cidrs
      destination_addresses = local.client_cidrs
      destination_ports     = ["*"]
    }
  }

  network_rule_collection {
    name     = "allow-oracle"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "database-listener"
      protocols             = ["TCP"]
      source_addresses      = local.client_cidrs
      destination_addresses = [local.oracle_cidr]
      destination_ports     = ["1521", "22"]
    }
  }

  application_rule_collection {
    name     = "workshop-web-egress"
    priority = 300
    action   = "Allow"
    rule {
      name              = "packages-and-azure-login"
      source_addresses  = local.client_cidrs
      destination_fqdns = ["*"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_public_ip" "bastion" {
  provider            = azurerm.mhcore
  name                = "pip-workshop-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  provider            = azurerm.mhcore
  name                = "bas-workshop-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "Standard"
  tunneling_enabled   = true
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
  tags = var.tags
}

resource "azurerm_virtual_network_peering" "hub_to_odaa" {
  provider                     = azurerm.mhcore
  name                         = "peer-hub-to-odaa"
  resource_group_name          = azurerm_resource_group.hub.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.shared_odaa.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "odaa_to_hub" {
  provider                     = azurerm.mhodaa
  name                         = "peer-odaa-to-hub"
  resource_group_name          = azurerm_resource_group.shared_odaa.name
  virtual_network_name         = azurerm_virtual_network.shared_odaa.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_route_table" "odaa" {
  provider            = azurerm.mhodaa
  name                = "rt-odaa-return"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared_odaa.name
  tags                = var.tags
}

resource "azurerm_route" "odaa_to_client" {
  provider               = azurerm.mhodaa
  for_each               = toset(local.client_cidrs)
  name                   = "to-${replace(replace(each.key, ".", "-"), "/", "-")}"
  resource_group_name    = azurerm_resource_group.shared_odaa.name
  route_table_name       = azurerm_route_table.odaa.name
  address_prefix         = each.key
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "odaa" {
  provider       = azurerm.mhodaa
  subnet_id      = azurerm_subnet.shared_odaa.id
  route_table_id = azurerm_route_table.odaa.id
}

resource "azurerm_role_assignment" "hub_reader" {
  provider             = azurerm.mhcore
  scope                = azurerm_resource_group.hub.id
  role_definition_name = "Reader"
  principal_id         = local.workshop_group_id
}

resource "azurerm_role_assignment" "gallery_reader" {
  provider             = azurerm.mhcore
  scope                = azurerm_resource_group.shared.id
  role_definition_name = "Reader"
  principal_id         = local.workshop_group_id
}
