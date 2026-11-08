param location string
param participant string
param privateIp string
@minLength(36)
@maxLength(36)
param userObjectId string
param adminSshPublicKey string
param vmImageId string

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: 'vnet-vm-${participant}/snet-vm-${participant}'
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-vm-${participant}'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'internal'
      properties: {
        subnet: {
          id: subnet.id
        }
        privateIPAllocationMethod: 'Static'
        privateIPAddress: privateIp
      }
    }]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-${participant}'
  location: location
  zones: ['2']
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v7'
    }
    storageProfile: {
      diskControllerType: 'NVMe'
      imageReference: {
        id: vmImageId
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'vm-${participant}'
      adminUsername: 'azureuser'
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [{
            path: '/home/azureuser/.ssh/authorized_keys'
            keyData: adminSshPublicKey
          }]
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
      networkInterfaces: [{
        id: nic.id
      }]
    }
  }
}

resource aad 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'AADSSHLoginForLinux'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADSSHLoginForLinux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource login 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vm
  name: guid(vm.id, userObjectId, 'vm-user-login')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fb879df8-f326-4884-b1cf-06f3ad86be52')
    principalId: userObjectId
    principalType: 'User'
  }
}
