targetScope = 'resourceGroup'

param location string = 'francecentral'
@minLength(3)
@maxLength(253)
@description('Actual OCI subnet domain including the trailing dot; obtain from the provisioned anchor/OCI subnet.')
param oracleDnsDomain string
@minLength(7)
@maxLength(15)
param oracleDnsListeningIp string

resource resolver 'Microsoft.Network/dnsResolvers@2022-07-01' existing = {
  name: 'dns-workshop-hub'
}
resource outbound 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' existing = {
  parent: resolver
  name: 'dns-outbound'
}

resource ruleset 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' = {
  name: 'ruleset-oracle'
  location: location
  properties: {
    dnsResolverOutboundEndpoints: [{
      id: outbound.id
    }]
  }
}

resource rule 'Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01' = {
  parent: ruleset
  name: 'oracle-vcn'
  properties: {
    domainName: oracleDnsDomain
    forwardingRuleState: 'Enabled'
    targetDnsServers: [{
      ipAddress: oracleDnsListeningIp
      port: 53
    }]
  }
}

resource hub 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-workshop-hub'
}
resource link 'Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01' = {
  parent: ruleset
  name: 'link-workshop-hub'
  properties: {
    virtualNetwork: {
      id: hub.id
    }
  }
}
