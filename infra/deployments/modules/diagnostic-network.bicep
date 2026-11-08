param location string = 'francecentral'

var tags = {
  Project: 'OracleWorkshop'
  ManagedBy: 'Bicep'
}

resource routes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-hub-dns-diagnostic'
  location: location
  tags: tags
  properties: {
    routes: [{
      name: 'internet-via-firewall'
      properties: {
        addressPrefix: '0.0.0.0/0'
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: '10.100.0.4'
      }
    }]
  }
}

resource policy 'Microsoft.Network/firewallPolicies@2024-05-01' existing = {
  name: 'policy-workshop-firewall'
}

resource egress 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: policy
  name: 'diagnostic-egress'
  properties: {
    priority: 250
    ruleCollections: [{
      name: 'diagnostic-agent-downloads'
      priority: 100
      ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
      action: { type: 'Allow' }
      rules: [{
        name: 'azure-agent-storage'
        ruleType: 'ApplicationRule'
        sourceAddresses: ['10.100.1.0/28']
        targetFqdns: ['*.blob.${environment().suffixes.storage}']
        protocols: [{
          protocolType: 'Https'
          port: 443
        }]
      }]
    }]
  }
}

output routeTableId string = routes.id
