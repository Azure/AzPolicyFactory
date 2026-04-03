metadata itemDisplayName = 'Test Template for Network Security Group Rule'
metadata description = 'This template deploys the testing resource for Network Security Group Rule.'
metadata summary = 'Deploys test network security group rule resource that should be complaint with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var namePrefix = globalConfig.namePrefix

// define template specific variables
var existingServiceShort = 'nsg1'
var existingNsgName = 'nsg-${namePrefix}-${existingServiceShort}-01'

resource existingNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' existing = {
  name: existingNsgName
}

resource inboundRule1 'Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01' = {
  name: 'Allow-SQL-Inbound'
  parent: existingNsg
  properties: {
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '1433'
    destinationPortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork' //should be compliant with policy NSG-003
    destinationAddressPrefix: 'VirtualNetwork'
    priority: 400
    direction: 'Inbound'
  }
}

resource outboundRule1 'Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01' = {
  name: 'Allow-SSH-Outbound'
  parent: existingNsg
  properties: {
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '22'
    destinationPortRange: '22'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: 'AzureLoadBalancer' //should be compliant with policy NSG-004
    priority: 400
    direction: 'Outbound'
  }
}

output inboundRuleName string = inboundRule1.name
output outboundRuleName string = outboundRule1.name
output inboundRuleResourceId string = inboundRule1.id
output outboundRuleResourceId string = outboundRule1.id
output location string = existingNsg.location
