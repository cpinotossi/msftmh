param location string
param firewallPrivateIp string

var clientCidrs = ['10.0.1.0/24', '10.0.2.0/24', '10.0.3.0/24', '10.0.4.0/24', '10.0.5.0/24', '10.0.6.0/24', '10.0.7.0/24', '10.200.0.0/24']

resource routes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-odaa-return'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [for (cidr, i) in clientCidrs: {
      name: 'client-${i + 1}-via-hub'
      properties: {
        addressPrefix: cidr
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: firewallPrivateIp
      }
    }]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-odaa-shared'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['192.168.0.0/16']
    }
    subnets: [{
      name: 'snet-odaa-delegated'
      properties: {
        addressPrefix: '192.168.0.0/24'
        defaultOutboundAccess: false
        routeTable: {
          id: routes.id
        }
        delegations: [{
          name: 'oracle-delegation'
          properties: {
            serviceName: 'Oracle.Database/networkAttachments'
          }
        }]
      }
    }]
  }
}

resource anchor 'Oracle.Database/resourceAnchors@2025-09-01' = {
  name: 'anchor-odaa-shared'
  location: 'global'
  properties: {}
}

output odaaVnetId string = vnet.id
output odaaSubnetId string = '${vnet.id}/subnets/snet-odaa-delegated'
output resourceAnchorId string = anchor.id
