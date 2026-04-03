metadata itemDisplayName = 'Test Template for Virtual Network'
metadata description = 'This template deploys the testing resource for Virtual Network.'
metadata summary = 'Deploys test virtual network resource that should be compliant with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'vnet2'

var vnetName = 'vnet-${namePrefix}-${serviceShort}-01'
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
          sourceAddressPrefix: 'virtualNetwork'
          destinationAddressPrefix: '*'
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
        '10.100.0.0/16'
      ]
    }
  }

  resource subnet1 'subnets' = {
    name: 'subnet1'
    properties: {
      addressPrefix: '10.100.1.0/24'
      networkSecurityGroup: {
        id: nsg.id //this should comply with the policy VNET-002: Subnets should be associated with a Network Security Group
      }
    }
  }
  resource gatewaySubnet 'subnets' = {
    name: 'GatewaySubnet'
    properties: {
      addressPrefix: '10.100.250.0/24'
      //networkSecurityGroup: {
      //  id: nsg.id //this comply with the policy VNET-001: Gateway Subnet should not have Network Security Group associated
      //}
    }
  }
}

output name string = vnet.name
output resourceId string = vnet.id
output nsgResourceId string = nsg.id
output nsgName string = nsg.name
output location string = location
