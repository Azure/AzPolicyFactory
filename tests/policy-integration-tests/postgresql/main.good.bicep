metadata itemDisplayName = 'Test Template for PostgreSQL'
metadata description = 'This template deploys the testing resource for PostgreSQL.'
metadata summary = 'Deploys test PostgreSQL resources that should comply with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'pgs2'
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
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
    } // this should comply with policy PSG-001: A Microsoft Entra administrator should be provisioned for PostgreSQL servers
    network: {
      delegatedSubnetResourceId: virtualNetwork.properties.subnets[0].id
      privateDnsZoneArmResourceId: privateDNSZone.id
    } // this should comply with policy PGS-002: Public network access should be disabled for PostgreSQL flexible servers
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
