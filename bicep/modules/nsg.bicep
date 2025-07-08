@description('Azure region')
param location string

@description('Name for the NSG')
param nsgName string

@description('Full resource ID of the subnet to secure')
param subnetId string

@description('List of CIDRs to allow inbound (must have at least 2 entries)')
param allowedIPs array

@description('Address prefix of the subnet to associate (must match existing subnet exactly)')
param subnetAddressPrefix string

// Validate allowedIPs length
// This is a simple runtime check, Bicep currently has no built-in error throwing
var allowedIPsCount = length(allowedIPs)
var validAllowedIPs = allowedIPsCount >= 2 ? true : false

// 🔍 Extract VNet and Subnet name
var segments = split(subnetId, '/')
var vnetName = segments[8]
var subnetName = segments[10]

// Reference the existing VNet and Subnet
resource existingVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: subnetName
  parent: existingVnet
}

// Create the NSG
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      // Inbound Allow from first allowed IP
      {
        name: 'AllowManagement-0'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: validAllowedIPs ? allowedIPs[0] : '0.0.0.0/32' // fallback safe
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      // Inbound Allow from second allowed IP
      {
        name: 'AllowManagement-1'
        properties: {
          priority: 101
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: validAllowedIPs ? allowedIPs[1] : '0.0.0.0/32'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      // Deny all other inbound
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
      // Allow all outbound (best practice)
      {
        name: 'AllowAllOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
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

// Associate NSG to subnet
resource subnetAssoc 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: subnetName
  parent: existingVnet
  properties: {
    addressPrefix: subnetAddressPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

output nsgId string = nsg.id
