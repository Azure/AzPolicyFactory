metadata itemDisplayName = 'Test Template for xxx'
metadata description = 'This template deploys the testing resource for xxx.'
metadata summary = 'Deploys test xxx resources that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.disallowedLocation
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'cos3'
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' = {
  kind: 'GlobalDocumentDB'
  name: '${namePrefix}${serviceShort}01'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 300
      maxStalenessPrefix: 100001
    }
    locations: [
      {
        locationName: location // this should violate the policy COSMOS-007
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: false // this should violate the policy COSMOS-001
    enableMultipleWriteLocations: false
    networkAclBypass: 'AzureServices'
    enablePartitionMerge: false
    publicNetworkAccess: 'Enabled' // this should violate the policy COSMOS-002, COSMOS-003
    minimalTlsVersion: 'TLS1_1' // this should violate the policy COSMOS-006
    disableKeyBasedMetadataWriteAccess: false // this should violate the policy COSMOS-005
  }
}
