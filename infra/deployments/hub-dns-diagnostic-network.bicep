targetScope = 'resourceGroup'

resource hub 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-workshop-hub'
}

module diagnosticNetwork 'modules/diagnostic-network.bicep' = {
  name: 'diagnostic-routing-and-egress'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hub
  name: 'snet-dns-diagnostic'
  properties: {
    addressPrefix: '10.100.1.0/28'
    defaultOutboundAccess: false
    routeTable: { id: diagnosticNetwork.outputs.routeTableId }
  }
}
