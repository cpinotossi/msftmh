// ===============================================================================
// ADB Test Instance — Deployed by E2E test workflow
// Mirrors Challenge 2 settings: Transaction Processing, 26ai, 2 ECPU, 20GB
// ===============================================================================

@secure()
param adminPassword string

param subnetId string
param vnetId string
param location string = 'francecentral'
param adbName string = 'adbtest00'

resource adb 'Oracle.Database/autonomousDatabases@2025-03-01' = {
  name: adbName
  location: location
  properties: {
    displayName: adbName
    dataBaseType: 'Regular'
    dbWorkload: 'OLTP'
    dbVersion: '26ai'
    computeModel: 'ECPU'
    computeCount: 2
    isAutoScalingEnabled: false
    dataStorageSizeInGbs: 20
    isAutoScalingForStorageEnabled: false
    backupRetentionPeriodInDays: 1
    adminPassword: adminPassword
    licenseModel: 'BringYourOwnLicense'
    databaseEdition: 'EnterpriseEdition'
    characterSet: 'AL32UTF8'
    ncharacterSet: 'AL16UTF16'
    subnetId: subnetId
    vnetId: vnetId
  }
}

output adbId string = adb.id
output adbName string = adb.name
output privateEndpointIp string = adb.properties.privateEndpointIp
output privateEndpointLabel string = adb.properties.privateEndpointLabel
