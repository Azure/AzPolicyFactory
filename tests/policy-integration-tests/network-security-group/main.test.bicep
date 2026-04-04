metadata itemDisplayName = 'Test Template for Network Security Group'
metadata description = 'This template deploys the testing resource for Network Security Group.'
metadata summary = 'Deploys test network security group resource.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var tags = globalConfig.tags
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'nsg1'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-01'

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Inbound'
        properties: {
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '22'
          destinationPortRange: '22'
          sourceAddressPrefix: 'VirtualNetwork' //should be compliant with policy NSG-003
          destinationAddressPrefix: 'VirtualNetwork'
          priority: 200
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-RDP-Inbound'
        properties: {
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '3389'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          priority: 210
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '443'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          priority: 220
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-Outbound-SQL'
        properties: {
          access: 'Deny'
          protocol: 'Tcp'
          sourcePortRange: '1443'
          destinationPortRange: '1433'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud' //should be compliant with policy NSG-004
          priority: 4000
          direction: 'Outbound'
        }
      }
    ]
  }
}

output name string = nsg.name
output resourceId string = nsg.id
output location string = nsg.location
