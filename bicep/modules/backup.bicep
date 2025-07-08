@description('Azure region for the backup resources.')
param location string

@description('App name used for naming resources.')
param appName string

@description('Resource group name (passed for backup config).')
param resourceGroupName string

@description('Name of the App Service to backup.')
param appServiceName string

@description('PostgreSQL   string (e.g. Server=xxx;Database=xxx;User Id=xxx;Password=xxx;).')
@secure()
param postgresqlConnectionString string

@description('UTC time to start the backup (ISO8601 format).')
param backupStartTime string = '2025-07-04T00:00:00Z'

@description('Number of days to retain backups.')
param retentionDays int = 7

// ✅ Ensure valid storage account name
var sanitizedAppName = toLower(replace(appName, '-', ''))
var baseName = take('${sanitizedAppName}bkp', 18)
var backupStorageAccountName = '${baseName}sa'

// ✅ Storage Account
resource backupStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: backupStorageAccountName
  location: location
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Cool'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ✅ Blob container for backup data
resource backupContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${backupStorage.name}/default/backupcontainer'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    backupStorage
  ]
}

// ✅ Fetch storage account key
var storageAccountKey = listKeys(backupStorage.name, backupStorage.apiVersion).keys[0].value

// ✅ App Service Backup Config (with PostgreSQL)
resource appServiceBackup 'Microsoft.Web/sites/backup/config@2022-03-01' = {
  name: '${appServiceName}/backup/config'
  properties: {
    enabled: true
    backupSchedule: {
      frequencyInterval: 1
      frequencyUnit: 'Day'
      keepAtLeastOneBackup: true
      retentionPeriodInDays: retentionDays
      startTime: backupStartTime
    }
    storageAccountUrl: 'https://${backupStorage.name}.blob.core.windows.net/backupcontainer'
    storageAccountKey: storageAccountKey
    databases: [
      {
        connectionString: postgresqlConnectionString
        databaseType: 'PostgreSql' // ✅ THIS IS THE KEY FIX
      }
    ]
  }
  dependsOn: [
    backupContainer
  ]
}

output storageAccountName string = backupStorage.name
output backupContainerName string = backupContainer.name
