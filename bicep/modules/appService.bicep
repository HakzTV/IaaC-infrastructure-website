param location string = 'northeurope' // Default location, can be overridden
param appName string
param postgresqlFqdn string
// param adminPassword string
param identityId string
param vnetSubnetId string // For VNET Integration
param appInsightsInstrumentationKey string = ''
param logAnalyticsWorkspaceId string = ''
param keyVaultUri string
param storageAccountName string
param fileShareName string
// @secure()
// param storageAccountKey string
var storageKey = listKeys(storageAccountName, '2022-09-01').keys[0].value

// App Service Plan (Linux, PremiumV2)
resource plan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${appName}-plan'
  location: location
  sku: {
    name: 'P1v2'
    tier: 'PremiumV2'
    capacity: 1 // Start with 1 instance
  }
  kind: 'linux'
  properties: {
    reserved: true
    perSiteScaling: false
    zoneRedundant: true
  }
}

// App Service Web App with VNET Integration and Managed Identity
resource app 'Microsoft.Web/sites@2022-03-01' = {
  name: appName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|wordpress:latest'
      appSettings: [
        {
          name: 'DB_CONNECTION_STRING'
          value: 'Server=${postgresqlFqdn};Database=wordpress;User Id=wpadmin;Password=@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/adminPassword)'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'true'
        }

        {
          name: 'ADMIN_PASSWORD'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/adminPassword)'
        }
        {
          name: 'WEBSITE_LOCAL_CACHE_OPTION'
          value: 'Always'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
        }
        {
          name: 'LOG_ANALYTICS_WORKSPACE_ID'
          value: logAnalyticsWorkspaceId
        }
      ]
      virtualNetworkSubnetId: vnetSubnetId
      azureStorageAccounts: {
        wpcontent: {
          type: 'AzureFiles'
          accountName: storageAccountName
          shareName: fileShareName
          accessKey: storageKey
          mountPath: '/mnt/wp-content'
        }
      }
      ipSecurityRestrictions: [

        {
          name: 'AllowManagementIP'
          action: 'Allow'
          priority: 101
          ipAddress: '203.0.113.5/32' // Replace with your actual management IP
        }
        {
          name: 'DenyAllOthers'
          action: 'Deny'
          priority: 200
          ipAddress: '0.0.0.0/0'
        }
      ]
    }
    httpsOnly: true
  }
}
resource stagingSlot 'Microsoft.Web/sites/slots@2022-03-01' = {
  name: '${app.name}/staging' // 👈 slot under same app
  location: location
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|wordpress:latest'
      appSettings: [
        {
          name: 'DB_CONNECTION_STRING'
          value: 'Server=${postgresqlFqdn};Database=wordpress;User Id=wpadmin;Password=@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/adminPassword)'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'true'
        }
        {
          name: 'WEBSITE_LOCAL_CACHE_OPTION'
          value: 'Always'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'LOG_ANALYTICS_WORKSPACE_ID'
          value: logAnalyticsWorkspaceId
        }
      ]
      virtualNetworkSubnetId: vnetSubnetId
      azureStorageAccounts: {
        wpcontent: {
          type: 'AzureFiles'
          accountName: storageAccountName
          shareName: fileShareName
          accessKey: storageKey
          mountPath: '/mnt/wp-content'
        }
      }
    }
    httpsOnly: true
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  dependsOn: [
    app // ensure slot is created after app
  ]
}
// Auto-scale configuration for the App Service Plan
resource autoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${appName}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: plan.id
    profiles: [
      {
        name: 'defaultProfile'
        capacity: {
          minimum: '1'
          maximum: '5'
          default: '1'
        }
        rules: [
          // Scale out rule (CPU > 70%)
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: plan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          // Scale in rule (CPU < 30%)
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: plan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
    notifications: []
  }
}
// Diagnostics to Log Analytics (optional but recommended)
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appName}-diagnostics'
  scope: app
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output appServicePlanId string = plan.id
output appUrl string = app.properties.defaultHostName
output appServiceId string = app.id
output stagingSlotHostname string = 'https://${appName}.azurewebsites.net'
