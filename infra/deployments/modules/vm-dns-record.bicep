param participant string
param privateIp string

resource zone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'basedb.workshop.internal'
}

resource alias 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: zone
  name: 'vm-${participant}'
  properties: {
    ttl: 300
    aRecords: [{
      ipv4Address: privateIp
    }]
  }
}
