targetScope = 'resourceGroup'

param location string = 'francecentral'

resource gallery 'Microsoft.Compute/galleries@2023-07-03' = {
  name: 'gal_oracle_workshop'
  location: location
  properties: {
    description: 'Fixed seven-user Oracle BaseDB workshop client image'
  }
}

resource definition 'Microsoft.Compute/galleries/images@2023-07-03' = {
  parent: gallery
  name: 'oracle-workshop-vm'
  location: location
  properties: {
    osType: 'Linux'
    osState: 'Generalized'
    hyperVGeneration: 'V2'
    identifier: {
      publisher: 'OracleWorkshop'
      offer: 'oracle-tools'
      sku: 'ubuntu-2404'
    }
    features: [
      {
        name: 'SecurityType'
        value: 'TrustedLaunchSupported'
      }
      {
        name: 'DiskControllerTypes'
        value: 'SCSI,NVMe'
      }
    ]
  }
}

output imageDefinitionId string = definition.id
