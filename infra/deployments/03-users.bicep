targetScope = 'subscription'

type ParticipantIdentities = {
  mhuser1: string
  mhuser2: string
  mhuser3: string
  mhuser4: string
  mhuser5: string
  mhuser6: string
  mhuser7: string
}

param location string = 'francecentral'
param userObjectIds ParticipantIdentities
@minLength(36)
@maxLength(36)
param workshopGroupId string
@description('Organizer Entra user object ID for administrative login to all seven participant VMs.')
@minLength(36)
@maxLength(36)
param organizerObjectId string
param firewallPrivateIp string

var participants = [
  { name: 'mhuser1', cidr: '10.0.1.0/24', privateIp: '10.0.1.4' }
  { name: 'mhuser2', cidr: '10.0.2.0/24', privateIp: '10.0.2.4' }
  { name: 'mhuser3', cidr: '10.0.3.0/24', privateIp: '10.0.3.4' }
  { name: 'mhuser4', cidr: '10.0.4.0/24', privateIp: '10.0.4.4' }
  { name: 'mhuser5', cidr: '10.0.5.0/24', privateIp: '10.0.5.4' }
  { name: 'mhuser6', cidr: '10.0.6.0/24', privateIp: '10.0.6.4' }
  { name: 'mhuser7', cidr: '10.0.7.0/24', privateIp: '10.0.7.4' }
]
var hubVnetId = resourceId(subscription().subscriptionId, 'rg-workshop-hub', 'Microsoft.Network/virtualNetworks', 'vnet-workshop-hub')

module hubAccess './modules/hub-reader.bicep' = {
  name: 'hub-reader'
  scope: resourceGroup('rg-workshop-hub')
  params: {
    workshopGroupId: workshopGroupId
  }
}

module imageAccess './modules/hub-reader.bicep' = {
  name: 'image-reader'
  scope: resourceGroup('rg-workshop-images')
  params: {
    workshopGroupId: workshopGroupId
  }
}

resource groups 'Microsoft.Resources/resourceGroups@2024-03-01' = [for participant in participants: {
  name: 'rg-vm-${participant.name}'
  location: location
  tags: {
    Project: 'OracleWorkshop'
    Participant: participant.name
  }
}]

module networks './modules/spoke-network.bicep' = [for (participant, i) in participants: {
  name: 'network-${participant.name}'
  scope: groups[i]
  params: {
    location: location
    participant: participant.name
    spokeCidr: participant.cidr
    hubVnetId: hubVnetId
    firewallPrivateIp: firewallPrivateIp
  }
}]

@batchSize(1)
module hubPeerings './modules/hub-peering.bicep' = [for (participant, i) in participants: {
  name: 'hub-peering-${participant.name}'
  scope: resourceGroup('rg-workshop-hub')
  params: {
    peerName: 'peer-hub-to-${participant.name}'
    remoteVnetId: networks[i].outputs.vnetId
  }
}]

module access './modules/spoke-access.bicep' = [for (participant, i) in participants: {
  name: 'access-${participant.name}'
  scope: groups[i]
  params: {
    userObjectId: userObjectIds[participant.name]
    organizerObjectId: organizerObjectId
  }
}]

output userVnetIds array = [for participant in participants: resourceId(subscription().subscriptionId, 'rg-vm-${participant.name}', 'Microsoft.Network/virtualNetworks', 'vnet-vm-${participant.name}')]
