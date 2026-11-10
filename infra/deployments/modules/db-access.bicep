param groupObjectId string
param roleDefinitionId string

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, groupObjectId, 'basedb-creator')
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: groupObjectId
    principalType: 'Group'
  }
}
