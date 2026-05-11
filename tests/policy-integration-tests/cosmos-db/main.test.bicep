metadata itemDisplayName = 'Test Template for Cosmos DB'
metadata description = 'This template deploys the testing resource for Cosmos DB.'
metadata summary = 'Deploys test Cosmos DB resources.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
//Define required variables from the configuration files - change these based on your requirements
var tags = globalConfig.tags
var location = localConfig.location
var namePrefix = globalConfig.namePrefix
var subName = localConfig.testSubscription
var vnetResourceGroup = globalConfig.subscriptions[subName].networkResourceGroup
var vnetName = globalConfig.subscriptions[subName].vNet
var peSubnetName = globalConfig.subscriptions[subName].peSubnet

var serviceShort = 'cos1' //use this to form the name of the resources deployed by this template. This is helpful to identify the resource in the portal and also useful if you want to have a policy that targets specific resources by name. For example, if you have a policy that audits whether storage accounts have secure transfer enabled, you can set serviceShort to 'st' and then in the policy definition, you can target resources with name starting with 'st' to only audit the storage accounts deployed by this test template.

// ============ //
// resources    //
// ============ //
resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' = {
  kind: 'GlobalDocumentDB'
  name: '${namePrefix}${serviceShort}01'
  location: location
  tags: tags
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 300
      maxStalenessPrefix: 100001
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true
    enableMultipleWriteLocations: false
    networkAclBypass: 'AzureServices'
    enablePartitionMerge: false
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: 'TLS1_2'
    disableKeyBasedMetadataWriteAccess: true
    //keyVaultKeyUri: '' // this should violate the policy COSMOS-004
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: 'pe-${namePrefix}${serviceShort}-cosmosdb'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnet::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}${serviceShort}-cosmosdb'
        properties: {
          privateLinkServiceId: cosmosDb.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
}
// ============ //
// outputs      //
// ============ //
//Specify the outputs that are required for the test
