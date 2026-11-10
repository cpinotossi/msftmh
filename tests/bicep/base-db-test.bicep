targetScope = 'resourceGroup'

@allowed([
  'basetest01', 'basetest02', 'basetest03', 'basetest04', 'basetest05', 'basetest06', 'basetest07'
  'basedb1', 'basedb2', 'basedb3', 'basedb4', 'basedb5', 'basedb6', 'basedb7'
])
param dbSystemName string
@description('Exact shape returned by France Central metadata. No runtime fallback.')
param shape string
@description('Exact version returned by dbSystemDbVersions; prefer regional 26ai.')
param dbVersion string
param zone string
@allowed(['ECPU', 'OCPU'])
param computeModel string
param computeCount int
@minValue(256)
param storageSizeGb int
param sshPublicKey string
@secure()
param adminPassword string
param owner string
@description('Organizer-managed existing central resource anchor ARM ID.')
param resourceAnchorId string
@description('Organizer-managed existing central network anchor ARM ID for the selected zone.')
param networkAnchorId string

var ownership = {
  workshop: 'odaa'
  'managed-by': 'workshop-base-db'
  'automation-owner': owner
}

resource dbSystem 'Oracle.Database/dbSystems@2025-09-01' = {
  name: dbSystemName
  location: 'francecentral'
  zones: [zone]
  tags: ownership
  properties: {
    source: 'None'
    resourceAnchorId: resourceAnchorId
    networkAnchorId: networkAnchorId
    hostname: dbSystemName
    displayName: dbSystemName
    shape: shape
    dbVersion: dbVersion
    databaseEdition: 'EnterpriseEdition'
    licenseModel: 'LicenseIncluded'
    nodeCount: 1
    computeModel: computeModel
    computeCount: computeCount
    initialDataStorageSizeInGb: storageSizeGb
    dbSystemOptions: {
      storageManagement: 'LVM'
    }
    pdbName: 'WORKSHOP'
    sshPublicKeys: [sshPublicKey]
    adminPassword: adminPassword
  }
}
