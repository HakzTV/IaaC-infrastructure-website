@description('App name used for resource naming.')
param appName string

@description('Azure region for deployment.')
param location string

@description('Azure Storage Account for Azure File Share')

resource wpStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: toLower(replace('${appName}store', '-', ''))
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource wpFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: '${wpStorage.name}/default/wp-content'
  properties: {
    enabledProtocols: 'SMB'
    quota: 5120 // 5GB quota (adjust as needed)
  }
  dependsOn: [
    wpStorage
  ]
}

output storageAccountName string = toLower(replace('${appName}store', '-', ''))

output fileShareName string = 'wp-content'
