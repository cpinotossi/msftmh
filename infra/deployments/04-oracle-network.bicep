targetScope = 'subscription'

param location string = 'francecentral'
@minLength(36)
@maxLength(36)
param workshopGroupId string
param firewallPrivateIp string

var readerRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')

resource shared 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-odaa-shared'
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
    description: 'Manage all BaseDB systems in the shared workshop resource group; networking and anchors are read-only.'
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

module dbAccess './modules/db-access.bicep' = {
  name: 'db-access-shared'
  scope: shared
  params: {
    groupObjectId: workshopGroupId
    roleDefinitionId: dbCreator.id
  }
}

output odaaVnetId string = network.outputs.odaaVnetId
output odaaSubnetId string = network.outputs.odaaSubnetId
output resourceAnchorId string = network.outputs.resourceAnchorId
output dbCreatorRoleId string = dbCreator.id
