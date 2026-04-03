metadata itemDisplayName = 'Test Template for Virtual Network'
metadata description = 'This template deploys the testing resource for Virtual Network.'
metadata summary = 'Deploys test virtual network resource.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var location2 = localConfig.location2
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'vnet1'
var aeVnetName = 'vnet-${namePrefix}-${serviceShort}-01'
var aeNsgName = 'nsg-${namePrefix}-${serviceShort}-01'

var aseVnetName = 'vnet-${namePrefix}-${serviceShort}-02'
var aseNsgName = 'nsg-${namePrefix}-${serviceShort}-02'

//NSGs
resource aeNsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: aeNsgName
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
          sourceAddressPrefix: 'virtualNetwork'
          destinationAddressPrefix: '*'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource aseNsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: aseNsgName
  location: location2
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '443'
          destinationPortRange: '443'
          sourceAddressPrefix: 'virtualNetwork'
          destinationAddressPrefix: '*'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

//vnets
resource aeVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: aeVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }

  resource subnet 'subnets' = {
    name: 'subnet1'
    properties: {
      addressPrefix: '10.0.1.0/24'
      networkSecurityGroup: {
        id: aeNsg.id
      }
    }
  }
}

resource aseVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: aseVnetName
  location: location2
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
  }

  resource subnet 'subnets' = {
    name: 'subnet1'
    properties: {
      addressPrefix: '10.1.1.0/24'
      networkSecurityGroup: {
        id: aseNsg.id
      }
    }
  }
}

output name string = aeVnet.name
output resourceId string = aeVnet.id
output location string = location
output aseVNetName string = aseVnet.name
output aseVNetResourceId string = aseVnet.id
output location2 string = location2
