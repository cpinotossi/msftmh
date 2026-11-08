param participant string
param firewallPrivateIp string

resource table 'Microsoft.Network/routeTables@2024-05-01' existing = {
  name: 'rt-${participant}'
}

resource route 'Microsoft.Network/routeTables/routes@2024-05-01' = {
  parent: table
  name: 'oracle-via-hub'
  properties: {
    addressPrefix: '192.168.0.0/24'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: firewallPrivateIp
  }
}
