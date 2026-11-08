resource policy 'Microsoft.Network/firewallPolicies@2024-05-01' existing = {
  name: 'policy-workshop-firewall'
}

resource rules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: policy
  name: 'workshop-oracle'
  properties: {
    priority: 200
    ruleCollections: [{
      name: 'oracle-connectivity'
      priority: 100
      ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
      action: {
        type: 'Allow'
      }
      rules: [{
        name: 'database-listener-and-ssh'
        ruleType: 'NetworkRule'
        ipProtocols: ['TCP']
        sourceAddresses: ['10.0.1.0/24', '10.0.2.0/24', '10.0.3.0/24', '10.0.4.0/24', '10.0.5.0/24', '10.0.6.0/24', '10.0.7.0/24', '10.200.0.0/24']
        destinationAddresses: ['192.168.0.0/24']
        destinationPorts: ['1521', '22']
      }]
    }]
  }
}
