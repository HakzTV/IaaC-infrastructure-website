@description('Azure region')
param location string

@description('Name for the NSG')
param nsgName string

@description('Full resource ID of the subnet to secure')
param subnetId string

@description('List of CIDRs to allow inbound (up to N entries)')
param allowedIPs array
@description('Address prefix of the subnet to associate')
param subnetAddressPrefix string

// 🔍 Extract VNet and Subnet name
var segments = split(subnetId, '/')
var vnetName = segments[8]
var subnetName = segments[10]

// ✅ Reference the VNet created by vnet.bicep (as existing)
resource existingVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

// ✅ Reference the subnet inside the existing VNet
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: subnetName
  parent: existingVnet
}

// ✅ Create the NSG
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowManagement-0'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: allowedIPs[0]
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowManagement-1'
        properties: {
          priority: 101
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: allowedIPs[1]
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
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

// ✅ Associate the NSG to the subnet, but include addressPrefix
resource subnetAssoc 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: subnetName
  parent: existingVnet
  properties: {
    addressPrefix: subnetAddressPrefix
    // ✅ This avoids the "NoAddressPrefix" error
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

output nsgId string = nsg.id
