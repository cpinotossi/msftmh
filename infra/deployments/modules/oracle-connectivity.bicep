param hubVnetId string

resource oracleVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-odaa-shared'
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: oracleVnet
  name: 'peer-odaa-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}
