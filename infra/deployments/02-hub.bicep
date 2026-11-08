targetScope = 'resourceGroup'

param location string = 'francecentral'

var tags = {
  Project: 'OracleWorkshop'
  ManagedBy: 'Bicep'
}
var clientCidrs = [
  '10.0.1.0/24'
  '10.0.2.0/24'
  '10.0.3.0/24'
  '10.0.4.0/24'
  '10.0.5.0/24'
  '10.0.6.0/24'
  '10.0.7.0/24'
  '10.200.0.0/24'
]

resource hub 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-workshop-hub'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.100.0.0/16']
    }
    subnets: [
      {
        name: 'snet-dns-diagnostic'
        properties: {
          addressPrefix: '10.100.1.0/28'
          defaultOutboundAccess: false
          routeTable: {
            id: diagnosticNetwork.outputs.routeTableId
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.100.0.0/26'
          defaultOutboundAccess: false
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.100.0.64/26'
          defaultOutboundAccess: false
        }
      }
      {
        name: 'snet-dns-inbound'
        properties: {
          addressPrefix: '10.100.0.128/26'
          defaultOutboundAccess: false
          delegations: [
            {
              name: 'dns-resolver'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: 'snet-dns-outbound'
        properties: {
          addressPrefix: '10.100.0.192/26'
          defaultOutboundAccess: false
          delegations: [
            {
              name: 'dns-resolver'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
    ]
  }
}

resource resolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: 'dns-workshop-hub'
  location: location
  tags: tags
  properties: {
    virtualNetwork: {
      id: hub.id
    }
  }
}

resource inbound 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  parent: resolver
  name: 'dns-inbound'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        privateIpAllocationMethod: 'Static'
        privateIpAddress: '10.100.0.132'
        subnet: {
          id: '${hub.id}/subnets/snet-dns-inbound'
        }
      }
    ]
  }
}

resource outbound 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  parent: resolver
  name: 'dns-outbound'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '${hub.id}/subnets/snet-dns-outbound'
    }
  }
}

resource privateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'basedb.workshop.internal'
  location: 'global'
  tags: tags
}

resource zoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateZone
  name: 'link-workshop-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hub.id
    }
  }
}

resource firewallPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-workshop-firewall'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource policy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: 'policy-workshop-firewall'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
    dnsSettings: {
      enableProxy: true
      servers: ['10.100.0.132']
    }
    threatIntelMode: 'Alert'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: 'fw-workshop-hub'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: policy.id
    }
    ipConfigurations: [
      {
        name: 'configuration'
        properties: {
          subnet: {
            id: '${hub.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
  }
  dependsOn: [inbound]
}

resource rules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: policy
  name: 'workshop-base'
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: 'deny-client-to-client'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Deny'
        }
        rules: [
          {
            name: 'isolated-spokes'
            ruleType: 'NetworkRule'
            ipProtocols: ['Any']
            sourceAddresses: clientCidrs
            destinationAddresses: clientCidrs
            destinationPorts: ['*']
          }
        ]
      }
      {
        name: 'workshop-web-egress'
        priority: 200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'packages-and-azure-login'
            ruleType: 'ApplicationRule'
            sourceAddresses: clientCidrs
            targetFqdns: ['*']
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
          }
        ]
      }
    ]
  }
}

resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-workshop-bastion'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-workshop-hub'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'configuration'
        properties: {
          subnet: {
            id: '${hub.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

output hubVnetId string = hub.id
module diagnosticNetwork 'modules/diagnostic-network.bicep' = {
  name: 'diagnostic-routing-and-egress'
  params: {
    location: location
  }
  dependsOn: [policy]
}

output hubResourceGroupName string = resourceGroup().name
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output dnsResolverInboundIp string = inbound.properties.ipConfigurations[0].privateIpAddress
output centralDnsZoneName string = privateZone.name
output centralDnsZoneResourceGroupName string = resourceGroup().name
output hubBastionName string = bastion.name
