targetScope = 'resourceGroup'

param owner string
param adminSshPublicKey string

var location = 'francecentral'
var tags = {
  Project: 'OracleWorkshop'
  ManagedBy: 'Bicep'
  purpose: 'hub-dns-diagnostic'
  'automation-owner': owner
}

resource hub 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-workshop-hub'
  scope: resourceGroup('rg-workshop-hub')
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: hub
  name: 'snet-dns-diagnostic'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-hub-dns-diagnostic'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowDiagnosticDNS'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefixes: ['10.100.0.4', '10.100.0.132', '192.168.0.0/24']
          destinationPortRange: '53'
        }
      }
      {
        name: 'AllowAzureHost'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '168.63.129.16'
          destinationPortRanges: ['80', '32526']
        }
      }
      {
        name: 'AllowAgentDownload'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
        }
      }
      {
        name: 'DenyOtherOutbound'
        properties: {
          priority: 300
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-hub-dns-diagnostic'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: { id: nsg.id }
    dnsSettings: { dnsServers: ['10.100.0.4'] }
    ipConfigurations: [
      {
        name: 'internal'
        properties: {
          subnet: { id: subnet.id }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-hub-dns-diagnostic'
  location: location
  zones: ['2']
  tags: tags
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2as_v7' }
    storageProfile: {
      diskControllerType: 'NVMe'
      imageReference: {
        id: '${subscription().id}/resourceGroups/rg-workshop-images/providers/Microsoft.Compute/galleries/gal_oracle_workshop/images/oracle-workshop-vm/versions/1.1.0'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        diskSizeGB: 128
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    osProfile: {
      computerName: 'hub-dns-probe'
      adminUsername: 'azureuser'
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/azureuser/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: { deleteOption: 'Delete' }
        }
      ]
    }
  }
}
