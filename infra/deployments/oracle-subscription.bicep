targetScope = 'subscription'

@description('Oracle Marketplace plan publisher for organizer onboarding.')
@minLength(1)
param planPublisher string = 'oracle'

@minLength(1)
param planProduct string = 'oracle_database_at_azure'

@minLength(1)
param planName string = 'oracle_database_at_azure_pay_as_you_go'

resource oracleSubscription 'Oracle.Database/oracleSubscriptions@2025-09-01' = {
  name: 'default'
  plan: {
    publisher: planPublisher
    product: planProduct
    name: planName
  }
  properties: {}
}

output oracleSubscriptionId string = oracleSubscription.id
