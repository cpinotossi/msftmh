targetScope = 'subscription'

param location string = 'francecentral'
@minLength(36)
@maxLength(36)
param workshopGroupId string
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
param firewallPrivateIp string

var participants = ['mhuser1', 'mhuser2', 'mhuser3', 'mhuser4', 'mhuser5', 'mhuser6', 'mhuser7']
var readerRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')

resource shared 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-odaa-shared'
  location: location
}

resource dbGroups 'Microsoft.Resources/resourceGroups@2024-03-01' = [for participant in participants: {
  name: 'rg-odaa-${participant}'
  location: location
  tags: {
    Project: 'OracleWorkshop'
    Participant: participant
  }
}]

resource testGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-odaa-test'
  location: location
}

module network './modules/oracle-network.bicep' = {
  name: 'oracle-network'
  scope: shared
  params: {
    location: location
    firewallPrivateIp: firewallPrivateIp
  }
}

resource dbCreator 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'oracle-workshop-basedb-creator')
  properties: {
    roleName: 'Oracle Workshop BaseDB Creator'
    description: 'Manage BaseDB only in the assigned participant resource group; shared networking and anchors are read-only.'
    type: 'CustomRole'
    assignableScopes: [subscription().id]
    permissions: [{
      actions: [
        'Oracle.Database/dbSystems/*'
        'Microsoft.Resources/deployments/*'
        'Microsoft.Resources/subscriptions/resourceGroups/read'
      ]
      notActions: []
    }]
  }
}

resource catalogReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'oracle-workshop-catalog-reader')
  properties: {
    roleName: 'Oracle Workshop Catalog Reader'
    description: 'Read the Oracle cloud/SaaS details used by the portal, without modifying subscriptions or anchors.'
    type: 'CustomRole'
    assignableScopes: [subscription().id]
    permissions: [{
      actions: [
        'Oracle.Database/oracleSubscriptions/listCloudAccountDetails/action'
        'Oracle.Database/oracleSubscriptions/listSaasSubscriptionDetails/action'
      ]
      notActions: []
    }]
  }
}

resource reader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, workshopGroupId, 'oracle-reader')
  properties: {
    roleDefinitionId: readerRole
    principalId: workshopGroupId
    principalType: 'Group'
  }
}

resource catalogAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, workshopGroupId, 'oracle-catalog-access')
  properties: {
    roleDefinitionId: catalogReader.id
    principalId: workshopGroupId
    principalType: 'Group'
  }
}

module dbAccess './modules/db-access.bicep' = [for (participant, i) in participants: {
  name: 'db-access-${participant}'
  scope: dbGroups[i]
  params: {
    userObjectId: userObjectIds[participant]
    roleDefinitionId: dbCreator.id
  }
}]

output odaaVnetId string = network.outputs.odaaVnetId
output odaaSubnetId string = network.outputs.odaaSubnetId
output resourceAnchorId string = network.outputs.resourceAnchorId
output dbCreatorRoleId string = dbCreator.id
