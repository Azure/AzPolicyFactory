metadata itemDisplayName = 'Test Template for Azure Private Endpoint'
metadata description = 'This template deploys the testing resource for Azure Private Endpoint.'
metadata summary = 'Deploys test Azure Private Endpoint resources that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

var vnetName = 'vnet-${namePrefix}${serviceShort}01'
var amplsSubnetName = 'sn-ampls'
var vnetAddressPrefix = '10.200.0.0/16'
var amplsSubnetPrefix = '10.200.0.0/24'

// define template specific variables
var serviceShort = 'ampls1'
var privateLinkScopeName = 'ampls-${namePrefix}${serviceShort}01'
var privateLinkScopePrivateEndpointName = 'pe-${privateLinkScopeName}'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-01'

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '443'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }

  resource amplsSubnet 'subnets' = {
    name: amplsSubnetName
    properties: {
      addressPrefix: amplsSubnetPrefix
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
}

resource ampls 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: privateLinkScopeName
  location: 'global'
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'Open'
    }
  }
}

resource amplsPe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: privateLinkScopePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::amplsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: '${last(split(ampls.id, '/'))}-azuremonitor'
        properties: {
          privateLinkServiceId: ampls.id
          groupIds: [
            'azuremonitor' //should violate policy PE-002: groupId 'azuremonitor' for AMPLS private endpoint is not allowed
          ]
        }
      }
    ]
  }
}

// ---------- Outputs ----------
output name string = ampls.name
output resourceId string = ampls.id
output location string = ampls.location
output vnetResourceId string = vnet.id
output privateEndpointName string = privateLinkScopePrivateEndpointName
output privateEndpointResourceId string = amplsPe.id
output resourceGroupId string = resourceGroup().id
