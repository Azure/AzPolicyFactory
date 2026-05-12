metadata itemDisplayName = 'Test Template for xxx'
metadata description = 'This template deploys the testing resource for xxx.'
metadata summary = 'Deploys test xxx resources.'

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
  name: '${namePrefix}${serviceShort}01'
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
    disableLocalAuth: true
    allowProjectManagement: true
    customSubDomainName: '${namePrefix}${serviceShort}01'
    userOwnedStorage: [
      {
        resourceId: storage.id
      }
    ]
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: 'pe-${namePrefix}${serviceShort}-cognitive'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnet::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}${serviceShort}-cognitive'
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

resource storage 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: 'sa${namePrefix}${serviceShort}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
    allowCrossTenantReplication: false
    allowedCopyScope: 'AAD'
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource storagePe 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: 'pe-sa${namePrefix}${serviceShort}-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnet::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-sa${namePrefix}${serviceShort}-blob'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cognitiveService.id, storage.id, 'Storage Blob Data Contributor')
  properties: {
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor
    principalId: cognitiveService.identity.principalId
    principalType: 'ServicePrincipal'
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
