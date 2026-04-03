metadata itemDisplayName = 'Test Template for Virtual Network'
metadata description = 'This template deploys the testing resource for Virtual Network.'
metadata summary = 'Deploys test virtual network resource that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'vnet3'

var vnetName = 'vnet-${namePrefix}-${serviceShort}-01'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-01'

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

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.200.0.0/16'
      ]
    }
  }

  resource subnet1 'subnets' = {
    name: 'subnet1'
    properties: {
      addressPrefix: '10.200.1.0/24'
      //networkSecurityGroup: {
      //  id: nsg.id //this should violate the policy VNET-002: Subnets should be associated with a Network Security Group
      //}
    }
  }
  resource gatewaySubnet 'subnets' = {
    name: 'GatewaySubnet'
    properties: {
      addressPrefix: '10.200.250.0/24'
      networkSecurityGroup: {
        id: nsg.id //this should violate the policy VNET-001: Gateway Subnet should not have Network Security Group associated
      }
    }
  }
}

output name string = vnet.name
output resourceId string = vnet.id
output nsgResourceId string = nsg.id
output nsgName string = nsg.name
output location string = location
