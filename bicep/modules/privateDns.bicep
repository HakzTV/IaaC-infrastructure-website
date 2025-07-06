@description('The Private DNS Zone for PostgreSQL Flexible Server.')
param dnsZoneName string = 'privatelink.postgres.database.azure.com'

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
}
output dnsZoneId string = privateDnsZone.id
