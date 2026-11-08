resource "azurerm_private_dns_zone" "workshop" {
  provider            = azurerm.mhcore
  name                = var.odaa_dns_zone_name
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  provider              = azurerm.mhcore
  name                  = "link-workshop-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.workshop.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azapi_resource" "network_anchor" {
  type      = "Oracle.Database/networkAnchors@2025-09-01"
  name      = "nw-anchor-workshop"
  parent_id = azurerm_resource_group.shared_odaa.id
  location  = var.location
  tags      = var.tags
  body = {
    zones = [var.network_anchor_zone]
    properties = {
      resourceAnchorId                     = azapi_resource.resource_anchor.id
      subnetId                             = azurerm_subnet.shared_odaa.id
      ociVcnDnsLabel                       = var.oci_vcn_dns_label
      isOracleDnsListeningEndpointEnabled  = true
      isOracleDnsForwardingEndpointEnabled = true
      isOracleToAzureDnsZoneSyncEnabled    = false
      dnsListeningEndpointAllowedCidrs     = join(",", azurerm_subnet.hub["snet-dns-outbound"].address_prefixes)
      dnsForwardingRules = [{
        domainNames         = var.odaa_dns_zone_name
        forwardingIpAddress = azurerm_private_dns_resolver_inbound_endpoint.hub.ip_configurations[0].private_ip_address
      }]
    }
  }
  response_export_values = ["properties"]

  depends_on = [
    azurerm_virtual_network_peering.hub_to_odaa,
    azurerm_virtual_network_peering.odaa_to_hub,
    azurerm_subnet_route_table_association.odaa,
    azurerm_route.odaa_to_client,
  ]

  lifecycle {
    postcondition {
      condition     = can(cidrhost("${self.output.properties.dnsListeningEndpointIpAddress}/32", 0))
      error_message = "The Network Anchor must expose a valid DNS listening endpoint before configuring forwarding."
    }
  }
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "oracle" {
  provider                                   = azurerm.mhcore
  name                                       = "ruleset-oracle"
  location                                   = var.location
  resource_group_name                        = azurerm_resource_group.hub.name
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.hub.id]
  tags                                       = var.tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "oracle" {
  provider                  = azurerm.mhcore
  name                      = "oracle-vcn"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.oracle.id
  domain_name               = "${azapi_resource.network_anchor.output.properties.ociVcnDnsLabel}.oraclevcn.com."
  enabled                   = true
  target_dns_servers {
    ip_address = azapi_resource.network_anchor.output.properties.dnsListeningEndpointIpAddress
    port       = 53
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "hub" {
  provider                  = azurerm.mhcore
  name                      = "link-oracle-ruleset-hub"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.oracle.id
  virtual_network_id        = azurerm_virtual_network.hub.id
}
