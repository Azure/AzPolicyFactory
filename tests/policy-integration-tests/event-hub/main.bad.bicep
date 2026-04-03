metadata itemDisplayName = 'Test Template for Event Hub'
metadata description = 'This template deploys the testing resource for Event Hub.'
metadata summary = 'Deploys test event hub resource that should violate some policy assignments.'

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
var serviceShort = 'eh3'
var eventHubName = 'eh${namePrefix}${serviceShort}03'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
}

resource eventHub 'Microsoft.EventHub/namespaces@2025-05-01-preview' = {
  name: eventHubName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    disableLocalAuth: false // This should violate EH-001 - Event Hub Namespace should have Local Authentication disabled
    publicNetworkAccess: 'Enabled' // This should violate EH-003 - Disable Public Network Access
    minimumTlsVersion: '1.0' // This should violate EH-002 - Event Hub must have minimum TLS version configured as per standard
  }
}
output name string = eventHub.name
output resourceId string = eventHub.id
output location string = eventHub.location
