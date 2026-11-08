param location string
param participantEnvironmentsReady bool

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-workshop-github'
  location: location
}

var subjects = [
  { name: 'github-main', subject: 'repo:cpinotossi/msftmh:ref:refs/heads/main' }
  { name: 'github-mhuser1', subject: 'repo:cpinotossi/msftmh:environment:mhuser1' }
  { name: 'github-mhuser2', subject: 'repo:cpinotossi/msftmh:environment:mhuser2' }
  { name: 'github-mhuser3', subject: 'repo:cpinotossi/msftmh:environment:mhuser3' }
  { name: 'github-mhuser4', subject: 'repo:cpinotossi/msftmh:environment:mhuser4' }
  { name: 'github-mhuser5', subject: 'repo:cpinotossi/msftmh:environment:mhuser5' }
  { name: 'github-mhuser6', subject: 'repo:cpinotossi/msftmh:environment:mhuser6' }
  { name: 'github-mhuser7', subject: 'repo:cpinotossi/msftmh:environment:mhuser7' }
]

@batchSize(1)
resource credentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = [for entry in subjects: if (entry.name == 'github-main' || participantEnvironmentsReady) {
  parent: identity
  name: entry.name
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    audiences: ['api://AzureADTokenExchange']
    subject: entry.subject
  }
}]

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
output tenantId string = identity.properties.tenantId
