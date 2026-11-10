@minLength(36)
@maxLength(36)
param userObjectId string

@minLength(36)
@maxLength(36)
param organizerObjectId string

resource contributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, userObjectId, 'own-spoke-contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: userObjectId
    principalType: 'User'
  }

}

resource organizerLogin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, organizerObjectId, 'organizer-vm-admin-login')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1c0163c0-47e6-4577-8991-ea5c82e286e4')
    principalId: organizerObjectId
    principalType: 'User'
  }
}
