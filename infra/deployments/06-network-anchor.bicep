targetScope = 'resourceGroup'

param location string = 'francecentral'
@allowed(['1', '2', '3'])
param zone string = '1'

resource resourceAnchor 'Oracle.Database/resourceAnchors@2025-09-01' existing = {
  name: 'anchor-odaa-shared'
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: 'vnet-odaa-shared/snet-odaa-delegated'
}

resource anchor 'Oracle.Database/networkAnchors@2025-09-01' = {
  name: 'nw-anchor-workshop'
  location: location
  zones: [zone]
  tags: {
    Project: 'OracleWorkshop'
    ManagedBy: 'Bicep'
  }
  properties: {
    resourceAnchorId: resourceAnchor.id
    subnetId: subnet.id
    ociVcnDnsLabel: 'mhworkshop'
    isOracleDnsListeningEndpointEnabled: true
    isOracleDnsForwardingEndpointEnabled: true
    isOracleToAzureDnsZoneSyncEnabled: false
    dnsListeningEndpointAllowedCidrs: '10.100.0.192/26'
    dnsForwardingRules: [{
      domainNames: 'basedb.workshop.internal'
      forwardingIpAddress: '10.100.0.132'
    }]
  }
}

output networkAnchorId string = anchor.id
output networkAnchorZone string = zone
output oracleDnsListeningIp string = anchor.properties.dnsListeningEndpointIpAddress
output oracleDnsForwardingIp string = anchor.properties.dnsForwardingEndpointIpAddress
output ociVcnId string = anchor.properties.ociVcnId
