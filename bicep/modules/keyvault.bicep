param location string
param keyVaultName string
param adminPassword string
param identityPrincipalId string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enablePurgeProtection: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: identityPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

resource adminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVault.name}/adminPassword'
  properties: {
    value: adminPassword
  }
  dependsOn: [
    keyVault
  ]
}
resource keyVaultAccess 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVault.id, identityPrincipalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    principalId: identityPrincipalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    ) // Key Vault Secrets User
    principalType: 'ServicePrincipal'
  }
}
output keyVaultUri string = keyVault.properties.vaultUri

// // Assign access policy to MSI for secret get/list
// resource accessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
//   name: '${keyVault.name}/add'
//   properties: {
//     accessPolicies: [
//       {
//         tenantId: subscription().tenantId
//         objectId: identityPrincipalId
//         permissions: {
//           secrets: [
//             'get'
//             'list'
//           ]
//         }
//       }
//     ]
//   }
//   dependsOn: [
//     keyVault
//   ]
// }

// output keyVaultUri string = keyVault.properties.vaultUri
