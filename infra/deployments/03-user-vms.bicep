targetScope = 'subscription'

param location string = 'francecentral'
type ParticipantIdentities = {
  mhuser1: string
  mhuser2: string
  mhuser3: string
  mhuser4: string
  mhuser5: string
  mhuser6: string
  mhuser7: string
}

param userObjectIds ParticipantIdentities
@minLength(1)
param adminSshPublicKey string
param vmImageId string = '/subscriptions/aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483/resourceGroups/rg-workshop-images/providers/Microsoft.Compute/galleries/gal_oracle_workshop/images/oracle-workshop-vm/versions/1.1.0'

var participants = [
  { name: 'mhuser1', privateIp: '10.0.1.4' }
  { name: 'mhuser2', privateIp: '10.0.2.4' }
  { name: 'mhuser3', privateIp: '10.0.3.4' }
  { name: 'mhuser4', privateIp: '10.0.4.4' }
  { name: 'mhuser5', privateIp: '10.0.5.4' }
  { name: 'mhuser6', privateIp: '10.0.6.4' }
  { name: 'mhuser7', privateIp: '10.0.7.4' }
]

module clients './modules/client-vm.bicep' = [for participant in participants: {
  name: 'client-${participant.name}'
  scope: resourceGroup('rg-vm-${participant.name}')
  params: {
    location: location
    participant: participant.name
    privateIp: participant.privateIp
    userObjectId: userObjectIds[participant.name]
    adminSshPublicKey: adminSshPublicKey
    vmImageId: vmImageId
  }
}]

module aliases './modules/vm-dns-record.bicep' = [for (participant, i) in participants: {
  name: 'dns-${participant.name}'
  scope: resourceGroup('rg-workshop-hub')
  params: {
    participant: participant.name
    privateIp: participant.privateIp
  }
  dependsOn: [clients[i]]
}]

output userVmIds array = [for participant in participants: resourceId(subscription().subscriptionId, 'rg-vm-${participant.name}', 'Microsoft.Compute/virtualMachines', 'vm-${participant.name}')]
