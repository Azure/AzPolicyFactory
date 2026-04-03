metadata itemDisplayName = 'Test Template for PostgreSQL'
metadata description = 'This template deploys the testing resource for PostgreSQL.'
metadata summary = 'Deploys test PostgreSQL resources.'

@description('Optional. The password to leverage for the login.')
@secure()
param password string = newGuid()
// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

//Define required variables from the configuration files - change these based on your requirements
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

var serviceShort = 'pgs4' //use this to form the name of the resources deployed by this template. This is helpful to identify the resource in the portal and also useful if you want to have a policy that targets specific resources by name. For example, if you have a policy that audits whether storage accounts have secure transfer enabled, you can set serviceShort to 'st' and then in the policy definition, you can target resources with name starting with 'st' to only audit the storage accounts deployed by this test template.
var postgreSqlName = 'psql-${namePrefix}${serviceShort}01'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-02'
var virtualNetworkName = 'vnet-${namePrefix}-${serviceShort}-01'
var routeTableName = 'rt-${namePrefix}-${serviceShort}-01'
var managedIdentityName = 'mi-${namePrefix}-${serviceShort}-01'

// ============ //
// resources    //
// ============ //

var addressPrefix = '10.100.0.0/16'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          access: 'Allow'
          description: 'Allow HTTPS Inbound on TCP port 443'
          protocol: 'Tcp'
          sourceAddressPrefix: 'virtualNetwork'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          direction: 'Inbound'
          priority: 200
        }
      }
    ]
  }
}
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: '${serviceShort}.postgres.database.azure.com'
  location: 'global'

  resource virtualNetworkLinks 'virtualNetworkLinks@2024-06-01' = {
    name: '${virtualNetwork.name}-vnetlink'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}
resource routeTable 'Microsoft.Network/routeTables@2025-05-01' = {
  name: routeTableName
  location: location
  properties: {
    routes: []
  }
}
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: virtualNetworkName
  location: location

  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'subnet1'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 0)
          networkSecurityGroup: {
            id: nsg.id
          }
          routeTable: {
            id: routeTable.id
          }
          delegations: [
            {
              name: 'Microsoft.DBforPostgreSQL.flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
    ]
  }
}

resource postgresql 'Microsoft.DBforPostgreSQL/flexibleServers@2026-01-01-preview' = {
  name: postgreSqlName
  location: location
  sku: {
    name: 'Standard_D2s_v3'
    tier: 'GeneralPurpose'
  }

  properties: {
    createMode: 'Default'
    administratorLogin: 'adminUserName'
    administratorLoginPassword: password
    authConfig: {
      activeDirectoryAuth: 'Disabled' // this should violate policy PSG-001: A Microsoft Entra administrator should be provisioned for PostgreSQL servers
      passwordAuth: 'Enabled'
    }
    network: {} // this should violate policy PGS-002: Public network access should be disabled for PostgreSQL flexible servers
  }
}

// ============ //
// outputs      //
// ============ //
output defaultSubnetResourceId string = virtualNetwork.properties.subnets[0].id
output virtualNetworkResourceId string = virtualNetwork.id
output privateDnsZoneResourceId string = privateDNSZone.id
output routeTableResourceId string = routeTable.id
output managedIdentityResourceId string = managedIdentity.id
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output name string = postgresql.name
output resourceId string = postgresql.id
output location string = postgresql.location
