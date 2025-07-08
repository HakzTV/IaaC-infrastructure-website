@description('The Private DNS Zone for PostgreSQL Flexible Server.')
param dnsZoneName string = 'privatelink.postgres.database.azure.com'

@description('ID of the VNET to link the Private DNS Zone to.')
param vnetId string
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'link-to-${uniqueString(vnetId)}'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false // Disable auto-registration of VMs in this VNET
  }
}
output dnsZoneId string = privateDnsZone.id
