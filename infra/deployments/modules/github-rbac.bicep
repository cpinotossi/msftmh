targetScope = 'subscription'

@minLength(36)
@maxLength(36)
param principalId string

var roles = [
  'b24988ac-6180-42a0-ab88-20f7382dd24c'
  '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
]

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roles: {
  name: guid(subscription().id, principalId, role)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
  }
}]
