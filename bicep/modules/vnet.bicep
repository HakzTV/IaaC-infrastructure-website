param location string
param ddosProtectionPlanId string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'wp-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    ddosProtectionPlan: {
      id: ddosProtectionPlanId // Reference the DDoS Protection Plan
    }
    enableDdosProtection: true
    subnets: [
      {
        name: 'postgresql-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'postgresqlDelegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: 'appservice-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output postgresSubnetId string = vnet.properties.subnets[0].id

output appSubnetId string = vnet.properties.subnets[1].id
// ✅ Add these two lines:
output mysqlSubnetPrefix string = vnet.properties.subnets[0].properties.addressPrefix
output appSubnetPrefix string = vnet.properties.subnets[1].properties.addressPrefix
