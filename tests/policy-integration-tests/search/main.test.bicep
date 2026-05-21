metadata itemDisplayName = 'Test Template for AI Search Service'
metadata description = 'This template deploys the testing resource for AI Search Service.'
metadata summary = 'Deploys test AI Search Service resources.'

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
var serviceShort = 'srch1' //use this to form the name of the resources deployed by this template. This is helpful to identify the resource in the portal and also useful if you want to have a policy that targets specific resources by name. For example, if you have a policy that audits whether storage accounts have secure transfer enabled, you can set serviceShort to 'st' and then in the policy definition, you can target resources with name starting with 'st' to only audit the storage accounts deployed by this test template.

// ============ //
// resources    //
// ============ //
resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
}

resource searchService 'Microsoft.Search/searchServices@2026-03-01-preview' = {
  name: '${namePrefix}${serviceShort}01'
  location: location
  tags: tags
  sku: {
    name: 'standard'
  }
  properties: {
    hostingMode: 'Default'
    publicNetworkAccess: 'Disabled'
    replicaCount: 1
    partitionCount: 1
    computeType: 'Default'
    disableLocalAuth: false //This should be modified to true by the policy SRCH-002: Configure Azure AI Search services to disable local authentication
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: 'pe-${namePrefix}${serviceShort}01'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnet::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}${serviceShort}01'
        properties: {
          privateLinkServiceId: searchService.id
          groupIds: [
            'searchService'
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
output name string = searchService.name
output resourceId string = searchService.id
output privateEndpointResourceId string = pe.id
output location string = searchService.location
