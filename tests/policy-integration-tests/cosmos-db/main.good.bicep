metadata itemDisplayName = 'Test Template for xxxx'
metadata description = 'This template deploys the testing resource for xxxx.'
metadata summary = 'Deploys test xxxx resources that should comply with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'cos2'
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
        locationName: location // this should comply with the policy COSMOS-007
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true // this should comply with the policy COSMOS-001
    enableMultipleWriteLocations: false
    networkAclBypass: 'AzureServices'
    enablePartitionMerge: false
    publicNetworkAccess: 'Disabled' // this should comply with the policy COSMOS-002, COSMOS-003
    minimalTlsVersion: 'Tls12' // this should comply with the policy COSMOS-006
    disableKeyBasedMetadataWriteAccess: true // this should comply with the policy COSMOS-005
  }
}
