param appName string
param tenantId string
// param clientId string

resource authConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${appName}/authsettingsV2'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: 'https://sts.windows.net/${tenantId}/'
        }
        login: {
          loginParameters: []
        }
      }
    }
  }
}
