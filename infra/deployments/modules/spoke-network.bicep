param location string
param participant string
param spokeCidr string
param hubVnetId string
param firewallPrivateIp string

resource routes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${participant}'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'internet-via-hub'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'oracle-via-hub'
        properties: {
          addressPrefix: '192.168.0.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-vm-${participant}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHubBastionSSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.100.0.64/26'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyOtherClientsInbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefixes: ['10.0.0.0/16', '10.200.0.0/24']
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowFirewallDNS'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: firewallPrivateIp
          sourcePortRange: '*'
          destinationPortRange: '53'
        }
      }
      {
        name: 'DenyOtherDNS'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '53'
        }
      }
      {
        name: 'DenyAzurePlatformDNS'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzurePlatformDNS'
          sourcePortRange: '*'
          // AzurePlatformDNS requires wildcard ports, not an explicit DNS port.
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyOtherClientsOutbound'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefixes: ['10.0.0.0/16', '10.200.0.0/24']
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-vm-${participant}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [spokeCidr]
    }
    dhcpOptions: {
      dnsServers: [firewallPrivateIp]
    }
    subnets: [{
      name: 'snet-vm-${participant}'
      properties: {
        addressPrefix: spokeCidr
        defaultOutboundAccess: false
        networkSecurityGroup: {
          id: nsg.id
        }
        routeTable: {
          id: routes.id
        }
      }
    }]
  }
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: vnet
  name: 'peer-${participant}-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

output vnetId string = vnet.id
