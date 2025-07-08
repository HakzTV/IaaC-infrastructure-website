@description('Name of the CDN Profile (must be globally unique within Azure CDN)')
param cdnProfileName string

@description('Name of the CDN Endpoint')
param cdnEndpointName string

@description('App Service Default Hostname (e.g. myapp.azurewebsites.net)')
param appServiceHostName string

@description('Location (should be global for CDN)')
param location string = 'global'

resource cdnProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: cdnProfileName
  location: location
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2021-06-01' = {
  name: '${cdnProfile.name}/${cdnEndpointName}'
  location: location
  properties: {
    isHttpAllowed: false
    isHttpsAllowed: true
    originHostHeader: appServiceHostName
    origins: [
      {
        name: 'origin1'
        properties: {
          hostName: appServiceHostName
          httpsPort: 443
        }
      }
    ]
    contentTypesToCompress: [
      'text/plain'
      'text/css'
      'application/javascript'
      'application/json'
      'text/html'
      'application/xml'
      'application/x-javascript'
      'image/svg+xml'
    ]
    isCompressionEnabled: true
  }
  dependsOn: [
    cdnProfile
  ]
}

output cdnEndpointUrl string = 'https://${cdnEndpoint.name}.azureedge.net'
