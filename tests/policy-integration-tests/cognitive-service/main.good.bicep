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
var serviceShort = 'cog2'

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2026-03-01' = {
  name: '${namePrefix}${serviceShort}01'
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  } //identity defined, this should comply with the policy COG-003
  properties: {
    networkAcls: {
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled' //this should comply with the policy COG-002
    disableLocalAuth: true //this should comply with the policy COG-001
    allowProjectManagement: true
    customSubDomainName: '${namePrefix}${serviceShort}01'
    userOwnedStorage: [
      {
        resourceId: storage.id
      }
    ] //user owned storage defined, this should comply with the policy COG-004
  }
}
resource gpt41 'Microsoft.CognitiveServices/accounts/deployments@2026-03-01' = {
  name: 'gpt41'
  parent: cognitiveService
  properties: {
    model: {
      name: 'gpt-4.1'
      format: 'OpenAI'
    }
  }
}

resource grok420reasoning 'Microsoft.CognitiveServices/accounts/deployments@2026-03-01' = {
  name: 'grok-4-20-reasoning'
  parent: cognitiveService
  properties: {
    model: {
      name: 'grok-4'
      format: 'xAI'
    }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: 'sa${namePrefix}${serviceShort}'
  location: location
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
