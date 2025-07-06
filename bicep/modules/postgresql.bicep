@description('Azure region that supports ZoneRedundant HA for PostgreSQL Flexible Server.')
param location string = 'uksouth'

@description('Name of the PostgreSQL Flexible Server.')
param serverName string
@description('Resource ID of the Private DNS zone for MySQL ')
param privateDnsZoneArmResourceId string

@description('The administrator password for the PostgreSQL server.')
@secure()
param adminPassword string

@description('Delegated subnet resource ID for the PostgreSQL Flexible Server.')
param subnetId string

resource postgresql 'Microsoft.DBforPostgreSQL/flexibleServers@2022-01-20-preview' = {
  name: serverName
  location: location
  sku: {
    name: 'Standard_D2ds_v4' // ✅ Cost-effective HA-capable SKU
    tier: 'GeneralPurpose'
    capacity: 2
  }
  properties: {
    version: '14' // ✅ Stable and compatible
    administratorLogin: 'wpadmin'
    administratorLoginPassword: adminPassword
    highAvailability: {
      mode: 'ZoneRedundant' // ✅ Enables HA across zones
    }
    storage: {
      storageSizeGB: 128
      autoGrow: 'Enabled'
    }
    network: {
      delegatedSubnetResourceId: subnetId
      privateDnsZoneArmResourceId: privateDnsZoneArmResourceId
    }
    createMode: 'Default'
  }
}

output postgresqlFqdn string = postgresql.properties.fullyQualifiedDomainName
output postgresqlId string = postgresql.id
