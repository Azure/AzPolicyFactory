metadata itemDisplayName = 'Test Template for AI Search Service'
metadata description = 'This template deploys the testing resource for AI Search Service.'
metadata summary = 'Deploys test AI Search Service resources that should comply with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'srch2'

resource searchService 'Microsoft.Search/searchServices@2026-03-01-preview' = {
  name: '${namePrefix}${serviceShort}01'
  location: location
  sku: {
    name: 'standard' //This should comply with policy SRCH-001: Azure AI Search service should use a SKU that supports private link, since Basic SKU does not support private link
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hostingMode: 'Default'
    publicNetworkAccess: 'Disabled' //This should comply with policy SRCH-003: Azure AI Search services should restrict public network access
    replicaCount: 1
    partitionCount: 1
    computeType: 'Default'
  }
}
