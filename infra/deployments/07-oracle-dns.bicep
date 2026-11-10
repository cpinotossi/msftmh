targetScope = 'resourceGroup'

@minLength(3)
@maxLength(253)
@description('Actual Azure private DNS zone created by Oracle during BaseDB provisioning, without a trailing dot.')
param oracleDnsZoneName string

resource zone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: oracleDnsZoneName
}

resource hub 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-workshop-hub'
  scope: resourceGroup('aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483', 'rg-workshop-hub')
}

resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: zone
  name: 'link-workshop-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hub.id
    }
  }
}

output oracleDnsZoneId string = zone.id
