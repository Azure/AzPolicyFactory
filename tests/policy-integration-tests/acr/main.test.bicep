metadata itemDisplayName = 'Test Template for Container Registry'
metadata description = 'This template deploys the testing resource for Container Registry.'
metadata summary = 'Deploys test Container Registry resource.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
//var tags = globalConfig.tags
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'acr1'
var acrName = 'acr${namePrefix}${serviceShort}01'
var routeTableName = 'rt-${namePrefix}-${serviceShort}-01'
var vnetName = 'vnet-${namePrefix}-${serviceShort}-01'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-01'
var peName = 'pe-${namePrefix}${serviceShort}-01'

var groupName = 'registry'

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          description: 'Allow HTTPS Inbound on TCP port 443'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'virtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2024-01-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: true
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Subnet-1'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          routeTable: {
            id: routeTable.id
          }
        }
      }
    ]
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'None'
    networkRuleSet: {
      defaultAction: 'Deny'
    }
    policies: {
      exportPolicy: { status: 'disabled' }
    }
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: peName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: peName
        properties: {
          groupIds: [
            groupName
          ]
          privateLinkServiceId: acr.id
        }
      }
    ]
    subnet: {
      id: virtualNetwork.properties.subnets[0].id
    }
  }
}

output name string = acr.name
output resourceId string = acr.id
output location string = acr.location
output privateEndpointResourceId string = pe.id
