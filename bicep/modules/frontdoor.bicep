param frontdoorName string
param customDomain string
param backendHost string
param wafPolicyName string

// e.g., telvinis.online ➜ telvinis-online
var customDomainNameSafe = toLower(replace(customDomain, '.', '-'))

// ✅ Front Door Profile (Standard SKU)
resource frontdoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontdoorName
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}

// ✅ Origin Group
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: '${frontdoorProfile.name}/originGroup1'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 120
    }
  }
  dependsOn: [ frontdoorProfile ]
}

// ✅ Origin
resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: '${originGroup.name}/appOrigin'
  properties: {
    hostName: backendHost
    httpsPort: 443
  }
  dependsOn: [ originGroup ]
}

// ✅ Endpoint
resource frontdoorEndpoint 'Microsoft.Cdn/profiles/endpoints@2021-06-01' = {
  name: '${frontdoorProfile.name}/${customDomainNameSafe}-endpoint'
  location: 'global'
  properties: {
    originGroup: {
      id: originGroup.id
    }
    originHostHeader: backendHost
    webApplicationFirewallPolicyLink: {
      id: resourceId('Microsoft.Network/frontdoorWebApplicationFirewallPolicies', wafPolicyName)
    }
  }
  dependsOn: [
    originGroup
  ]
}

// ✅ Custom Domain (safe `name`, real hostName)
resource frontdoorCustomDomain 'Microsoft.Cdn/profiles/customDomains@2021-06-01' = {
  name: '${frontdoorProfile.name}/www-${customDomainNameSafe}' // ✅ Name must NOT contain dots
  location: 'global'
  properties: {
    hostName: 'www.${customDomain}' // ✅ This can contain dots
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
  }
  dependsOn: [
    frontdoorEndpoint
  ]
}

output frontdoorHostname string = frontdoorEndpoint.properties.hostName
output siteUrl string = 'https://${frontdoorEndpoint.properties.hostName}'
