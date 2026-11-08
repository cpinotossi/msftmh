targetScope = 'subscription'

param location string = 'francecentral'
param participantEnvironmentsReady bool = false

resource ciGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-workshop-ci'
  location: location
}

module identity './modules/github-identity.bicep' = {
  name: 'github-identity'
  scope: ciGroup
  params: {
    location: location
    participantEnvironmentsReady: participantEnvironmentsReady
  }
}

module workshopRoles './modules/github-rbac.bicep' = {
  name: 'github-workshop-rbac'
  scope: subscription('aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483')
  params: {
    principalId: identity.outputs.principalId
  }
}

module oracleRoles './modules/github-rbac.bicep' = {
  name: 'github-oracle-rbac'
  scope: subscription('4ce5b5cc-e869-451f-98fc-f50448849ee0')
  params: {
    principalId: identity.outputs.principalId
  }
}

output clientId string = identity.outputs.clientId
output principalId string = identity.outputs.principalId
output tenantId string = identity.outputs.tenantId
