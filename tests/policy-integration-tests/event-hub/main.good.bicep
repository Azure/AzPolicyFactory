metadata itemDisplayName = 'Test Template for Event Hub'
metadata description = 'This template deploys the testing resource for Event Hub.'
metadata summary = 'Deploys test Event Hub resource that should be compliant with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix
var subName = localConfig.testSubscription
var vnetResourceGroup = globalConfig.subscriptions[subName].networkResourceGroup
var vnetName = globalConfig.subscriptions[subName].vNet
var peSubnetName = globalConfig.subscriptions[subName].peSubnet

// define template specific variables
var serviceShort = 'eh'
var eventHubName = 'eh${namePrefix}${serviceShort}02'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
}

resource eventHub 'Microsoft.EventHub/namespaces@2025-05-01-preview' = {
  name: eventHubName
  location: location
  sku: {
    name: 'Premium' // This should NOT violate EH-004 - Event Hub Namespace should have SKUs that support Private Links
  }
  properties: {
    disableLocalAuth: true // This should comply with EH-001 - Event Hub Namespace should have Local Authentication disabled
    publicNetworkAccess: 'Disabled' // This should comply with EH-003 - Disable Public Network Access
    minimumTlsVersion: '1.2' // This should comply with EH-002 - Event Hub must have minimum TLS version configured as per standard
  }
}

output name string = eventHub.name
output resourceId string = eventHub.id
output location string = eventHub.location
