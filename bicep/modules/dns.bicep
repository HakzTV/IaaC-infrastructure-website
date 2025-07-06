param domainName string
param frontdoorHostname string // just the hostname, e.g. frontdoorname.azurefd.net

resource dnsZone 'Microsoft.Network/dnsZones@2020-06-01' = {
  name: domainName
  location: 'global'
}

resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2020-06-01' = {
  name: 'www'
  parent: dnsZone
  properties: {
    TTL: 3600
    cnameRecord: {
      cname: frontdoorHostname // point CNAME to hostname ONLY
    }
  }
}

output dnsZoneName string = dnsZone.name
