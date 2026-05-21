metadata itemDisplayName = 'Test Template for AI Search Service'
metadata description = 'This template deploys the testing resource for AI Search Service.'
metadata summary = 'Deploys test AI Search Service resources that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'srch3'

resource searchService 'Microsoft.Search/searchServices@2026-03-01-preview' = {
  name: '${namePrefix}${serviceShort}01'
  location: location
  sku: {
    name: 'Basic' //This should violate policy SRCH-001: Azure AI Search service should use a SKU that supports private link, since Basic SKU does not support private link
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hostingMode: 'Default'
    publicNetworkAccess: 'Enabled' //This should violate policy SRCH-003: Azure AI Search services should restrict public network access
    replicaCount: 1
    partitionCount: 1
    computeType: 'Default'
  }
}
