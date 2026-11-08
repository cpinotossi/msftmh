targetScope = 'subscription'

param location string = 'francecentral'
param firewallPrivateIp string

var workshopSubscriptionId = 'aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483'
var oracleSubscriptionId = '4ce5b5cc-e869-451f-98fc-f50448849ee0'
var participants = ['mhuser1', 'mhuser2', 'mhuser3', 'mhuser4', 'mhuser5', 'mhuser6', 'mhuser7']

module hubPeering './modules/hub-peering.bicep' = {
  name: 'hub-to-oracle'
  scope: resourceGroup(workshopSubscriptionId, 'rg-workshop-hub')
  params: {
    peerName: 'peer-hub-to-odaa'
    remoteVnetId: resourceId(oracleSubscriptionId, 'rg-odaa-shared', 'Microsoft.Network/virtualNetworks', 'vnet-odaa-shared')
  }
}

module oracleRoutes './modules/oracle-connectivity.bicep' = {
  name: 'oracle-to-hub'
  scope: resourceGroup(oracleSubscriptionId, 'rg-odaa-shared')
  params: {
    hubVnetId: resourceId(workshopSubscriptionId, 'rg-workshop-hub', 'Microsoft.Network/virtualNetworks', 'vnet-workshop-hub')
  }
}

module clientRoutes './modules/oracle-client-route.bicep' = [for participant in participants: {
  name: 'oracle-route-${participant}'
  scope: resourceGroup(workshopSubscriptionId, 'rg-vm-${participant}')
  params: {
    participant: participant
    firewallPrivateIp: firewallPrivateIp
  }
}]

module rules './modules/oracle-firewall-rules.bicep' = {
  name: 'oracle-firewall-rules'
  scope: resourceGroup(workshopSubscriptionId, 'rg-workshop-hub')
}
