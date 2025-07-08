param appServiceName string
param appServicePlanName string
param domainName string
param subdomain string = 'www'
param location string = resourceGroup().location

// Managed Certificate
resource managedCert 'Microsoft.Web/certificates@2021-02-01' = {
  name: '${appServiceName}-${subdomain}-cert'
  location: location
  properties: {
    serverFarmId: resourceId('Microsoft.Web/serverfarms', appServicePlanName)
    hostNames: [
      '${subdomain}.${domainName}'
    ]
    validationMethod: 'Dns' // DNS validation via TXT record must exist (done in DNS module)
  }
}

// Bind certificate to custom domain on the App Service
resource hostnameBinding 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
  name: '${appServiceName}/${subdomain}.${domainName}'
  properties: {
    hostNameType: 'Verified'
  }
  dependsOn: [
    managedCert
  ]
}

output managedCertName string = managedCert.name
output hostnameBindingName string = hostnameBinding.name
