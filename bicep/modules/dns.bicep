param domainName string
param appServiceHostname string // just the hostname, e.g. frontdoorname.azurefd.net
param subdomain string = 'www' // subdomain to create CNAME for, e.g. 'www'
param appServiceName string // name of the App Service, e.g. 'myappservice'
param location string = 'global' // location for the DNS zone, typically 'global' for DNS

resource dnsZone 'Microsoft.Network/dnsZones@2020-06-01' = {
  name: domainName
  location: location
}

resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2020-06-01' = {
  name: subdomain
  parent: dnsZone
  properties: {
    TTL: 3600
    cnameRecord: {
      cname: appServiceHostname // point CNAME to hostname ONLY
    }
  }
}
// Create TXT record for domain verification by Azure
resource txtVerification 'Microsoft.Network/dnsZones/TXT@2020-06-01' = {
  name: '_dnsauth.${subdomain}'
  parent: dnsZone
  properties: {
    TTL: 3600
    txtRecords: [
      {
        value: [
          'asuid-${appServiceName}'
        ]
      }
    ]
  }
}

output cnameRecordName string = cnameRecord.name
