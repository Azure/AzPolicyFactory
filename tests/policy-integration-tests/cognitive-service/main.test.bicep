metadata itemDisplayName = 'Test Template for Cognitive Services'
metadata description = 'This template deploys the testing resource for Cognitive Services.'
metadata summary = 'Deploys test Cognitive Services resources.'

// ========== //
// Parameters //
// ========== //
@description('Optional. Get current time stamp. This is used to generate unique name for Cognitive Service account. DO NOT provide a value.')
param now string = utcNow()

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
var cognitiveServiceAccountNameSuffix = substring((uniqueString(now, location)), 0, 5)
var serviceShort = 'cog1' //use this to form the name of the resources deployed by this template. This is helpful to identify the resource in the portal and also useful if you want to have a policy that targets specific resources by name. For example, if you have a policy that audits whether storage accounts have secure transfer enabled, you can set serviceShort to 'st' and then in the policy definition, you can target resources with name starting with 'st' to only audit the storage accounts deployed by this test template.

// ============ //
// resources    //
// ============ //
resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
}

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2026-03-01' = {
  name: '${namePrefix}${serviceShort}${cognitiveServiceAccountNameSuffix}01'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    networkAcls: {
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
    allowProjectManagement: true
    customSubDomainName: '${namePrefix}${serviceShort}${cognitiveServiceAccountNameSuffix}01'
    //userOwnedStorage: [] //This should violate the audit policy COG-004 since no user owned storage defined
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: 'pe-${namePrefix}${serviceShort}${cognitiveServiceAccountNameSuffix}-cognitive'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnet::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}${serviceShort}${cognitiveServiceAccountNameSuffix}-cognitive'
        properties: {
          privateLinkServiceId: cognitiveService.id
          groupIds: [
            'account'
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
output name string = cognitiveService.name
output resourceId string = cognitiveService.id
output privateEndpointResourceId string = pe.id
output location string = cognitiveService.location
