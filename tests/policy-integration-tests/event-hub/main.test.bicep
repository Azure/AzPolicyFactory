metadata itemDisplayName = 'Test Template for Event Hub'
metadata description = 'This template deploys the testing resource for Event Hub.'
metadata summary = 'Deploys test storage account resource.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
//var tags = globalConfig.tags
var location = localConfig.location
var namePrefix = globalConfig.namePrefix
var subName = localConfig.testSubscription
var vnetResourceGroup = globalConfig.subscriptions[subName].networkResourceGroup
var vnetName = globalConfig.subscriptions[subName].vNet
var peSubnetName = globalConfig.subscriptions[subName].peSubnet

// define template specific variables
var serviceShort = 'eh1'
var eventHubName = 'eh${namePrefix}${serviceShort}01'
var eventHubNoPEName = 'eh${namePrefix}${serviceShort}02'

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
}

module eventHub 'br/public:avm/res/event-hub/namespace:0.14.1' = {
  name: '${uniqueString(deployment().name, location)}-test-${serviceShort}'
  params: {
    name: eventHubName
    disableLocalAuth: true
    managedIdentities: {
      systemAssigned: true
    }
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    skuName: 'Premium'
    zoneRedundant: false
    networkRuleSets: {
      defaultAction: 'Deny'
      ipRules: []
      publicNetworkAccess: 'Disabled'
    }
    privateEndpoints: [
      {
        name: 'pe-${eventHubName}-eh'
        service: 'namespace'
        subnetResourceId: vnet::peSubnet.id
      }
    ]
  }
}

module eventHubNoPe 'br/public:avm/res/event-hub/namespace:0.14.1' = {
  name: '${uniqueString(deployment().name, location)}-test-NoPe-${serviceShort}'
  params: {
    name: eventHubNoPEName
    disableLocalAuth: true
    managedIdentities: {
      systemAssigned: true
    }
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    skuName: 'Premium'
    zoneRedundant: false
    networkRuleSets: {
      defaultAction: 'Deny'
      ipRules: []
      publicNetworkAccess: 'Disabled'
    }
  }
}

output name string = eventHub.outputs.name
output resourceId string = eventHub.outputs.resourceId
output privateEndpointResourceId string = eventHub.outputs.privateEndpoints[0].resourceId
output eventHubNoPEName string = eventHubNoPe.outputs.name
output eventHubNoPEResourceId string = eventHubNoPe.outputs.resourceId
output location string = eventHub.outputs.location
