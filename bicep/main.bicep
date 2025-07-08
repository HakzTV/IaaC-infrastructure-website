// main.bicep

param location string = resourceGroup().location
param appName string
param postgresqlServerName string
param adminPassword string
param customDomain string
param tenantId string // Azure AD Tenant ID for Auth
// param aadClientId string // Azure AD App Registration Client ID
// param ddosProtectionPlanId string
param backupStartTime string = '2025-07-04T01:00:00Z'
param keyVaultName string

param dnsZoneName string = 'privatelink.postgres.database.azure.com'

//Network Configuration
// Deploy VNET first

module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  params: {
    location: location
  }
}

// DB Configuration
// Deploy postgreSQL Flexible Server in postgreSQL-subnet
module postgresql 'modules/postgresql.bicep' = {
  name: 'postgresql'
  params: {
    serverName: postgresqlServerName

    adminPassword: adminPassword
    subnetId: vnet.outputs.postgresSubnetId
    privateDnsZoneArmResourceId: privatedns.outputs.dnsZoneId
  }
  dependsOn: [
    vnet
    privatedns
  ]
}

var postgresqlFqdn = postgresql.outputs.postgresqlFqdn // FQDN for PostgresSQL Flexible Server
//User identity
// Create Managed Identity
module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    location: location
  }
}
module privatedns 'modules/privateDns.bicep' = {
  name: 'dnsZone'
  scope: resourceGroup(resourceGroup().name) // 👈 or use a parameter for flexibility
  params: {
    dnsZoneName: dnsZoneName
    vnetId: vnet.outputs.vnetId // Pass the VNET ID to link the DNS zone
  }
}

// Deploy Key Vault for secrets management
module keyvault './modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    keyVaultName: keyVaultName
    adminPassword: adminPassword
    identityPrincipalId: identity.outputs.principalId // Pass the MSI principalId here
  }
  dependsOn: [
    identity
  ]
}

// Deploy Monitoring (Log Analytics + App Insights)
module monitor 'modules/monitor.bicep' = {
  name: 'monitor'
  params: {
    location: location
    appName: appName
  }
}
module fileshare 'modules/fileshare.bicep' = {
  name: 'fileshare'
  params: {
    location: location
    appName: appName
  }
}

// Deploy WordPress App Service with VNET integration and MSI
module app 'modules/appService.bicep' = {
  name: 'app'
  params: {
    location: location
    appName: appName
    postgresqlFqdn: postgresql.outputs.postgresqlFqdn
    identityId: identity.outputs.identityId
    vnetSubnetId: vnet.outputs.appSubnetId
    appInsightsInstrumentationKey: monitor.outputs.appInsightsInstrumentationKey
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
    keyVaultUri: keyvault.outputs.keyVaultUri
    storageAccountName: fileshare.outputs.storageAccountName
    fileShareName: fileshare.outputs.fileShareName
  }
}
output appCheck string = app.outputs.appServiceId

// Configure DNS zone and CNAME pointing to Front Door
module dns 'modules/dns.bicep' = {
  name: 'dns'
  params: {
    domainName: customDomain
    location: 'global' // DNS zones are global
    appServiceHostname: app.outputs.appUrl // Use the App Service URL
    subdomain: 'www' // or any other subdomain you want to use
    appServiceName: appName // Pass the App Service name for CNAME creation
  }
  dependsOn: [
    app
  ]
}

// Configure NSG for App Service subnet
// Note: Ensure the allowed IPs match the ones in the NSG module
module nsg 'modules/nsg.bicep' = {
  name: 'deployNsg'
  params: {
    location: location
    nsgName: 'wp-app-nsg'
    subnetId: vnet.outputs.appSubnetId
    allowedIPs: [
      '203.0.113.5/32'
      '198.51.100.10/32'
      // add more here as needed, but remember to add a matching block above
    ]
    subnetAddressPrefix: vnet.outputs.appSubnetPrefix
  }
  dependsOn: [
    vnet
  ]
}
// Configure App Service Authentication with Azure AD
module auth 'modules/auth.bicep' = {
  name: 'auth'
  params: {
    appName: appName
    tenantId: tenantId
    // clientId: aadClientId
  }
  dependsOn: [
    app
  ]
}

//Backups
module backup 'modules/backup.bicep' = {
  name: 'backup'
  params: {
    location: location
    appName: appName
    resourceGroupName: resourceGroup().name
    appServiceName: appName
    postgresqlConnectionString: 'Server=${postgresqlFqdn};Database=wordpress;User Id=wpadmin;Password=${adminPassword}'
    backupStartTime: backupStartTime // set your desired backup start time UTC
    retentionDays: 7
  }
  dependsOn: [
    app
  ]
}
module alerts 'modules/alerts.bicep' = {
  name: 'alerts'
  params: {
    metricLocation: 'westeurope'
    queryLocation: 'westeurope'
    appName: appName
    appServiceResourceId: app.outputs.appServiceId
    appServicePlanResourceId: app.outputs.appServicePlanId
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
  }
}
module cdn 'modules/cdn.bicep' = {
  name: 'cdnDeploy'
  params: {
    cdnProfileName: 'telvin-cdn-profile'
    cdnEndpointName: 'telvin-cdn-endpoint'
    appServiceHostName: '${app.name}.azurewebsites.net'
    location: 'global'
  }
}

// Outputsa

output postgresqlFqdn string = postgresql.outputs.postgresqlFqdn
output appServiceUrl string = app.outputs.appUrl
output appServiceId string = app.outputs.appServiceId
output vnetId string = vnet.outputs.vnetId
output vnetSubnetId string = vnet.outputs.appSubnetId
output keyVaultUri string = keyvault.outputs.keyVaultUri
output identityId string = identity.outputs.identityId
