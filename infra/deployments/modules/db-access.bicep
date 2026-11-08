param userObjectId string
param roleDefinitionId string

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, userObjectId, 'basedb-creator')
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: userObjectId
    principalType: 'User'
  }
}
